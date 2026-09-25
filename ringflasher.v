`timescale 1ps/1ps
module ringflasher (
    input clk,
    input rst_n,
    input flick,
    output reg [15:0] led
);
    // N only ever holds 0..15. Declaring it as `integer` makes it a 32-bit
    // signed counter, which drags every comparison and the increment/decrement
    // up to 32 bits: synthesis reported 439 LUTs / 39 FFs that way versus
    // 43 LUTs / 11 FFs here, with identical behaviour.
    reg [3:0] N;
    integer i;
    reg [1:0] operation;

    parameter IDLE = 2'b00;
    parameter UP = 2'b01;
    parameter DOWN = 2'b10;
    parameter KICKBACK = 2'b11;

    parameter INIT          = 7'b0000001;
    parameter ON_0_TO_15    = 7'b0000010;
    parameter OFF_15_TO_5   = 7'b0000100;
    parameter ON_5_TO_10    = 7'b0001000;
    parameter OFF_10_TO_0   = 7'b0010000;
    parameter ON_0_TO_5     = 7'b0100000;
    parameter OFF_5_TO_0    = 7'b1000000;

    parameter SIZE = 7 ;
    reg [SIZE - 1:0] state;
    reg [SIZE - 1:0] next_state;

    //Change_state block
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= INIT;
        end
        else begin
            state <= next_state;
        end
    end

    //Logic block
    always@(*)begin
        operation = IDLE;

        case (state)
        INIT: begin
                operation = IDLE;
            end

        ON_0_TO_15: begin
            if(N < 15) 
                operation = UP;
            else 
                operation = DOWN;
        end

        OFF_15_TO_5:begin
            if(flick && (N == 5))
                operation = KICKBACK;
            else if (N > 5)
                operation = DOWN;
            else 
                operation = UP;
        end

        ON_5_TO_10:begin
            if(N < 10)
                operation = UP;
            else
                operation = DOWN;
        end

        OFF_10_TO_0:begin
            if(flick && (N == 0))
                operation = KICKBACK;
            else if(N > 0)
                operation = DOWN;
            else 
                operation = UP;
        end

        ON_0_TO_5:begin
            if(N < 5)
                operation = UP;
            else 
                operation = DOWN;
        end

        OFF_5_TO_0:begin
            if(N > 0)
                operation = DOWN;
            else    
                operation = IDLE;
        end
            default: operation = IDLE;
        endcase
    end


    //Operation block
    always@(posedge clk or negedge rst_n)begin
        if (!rst_n) begin
            N <= 0;
        end 
        else begin
        if (operation == UP)begin
            if(N < 15)
                N<=N + 1;
            else
                N <= 15;
            end 
        else if (operation == DOWN || operation == KICKBACK)begin
            if(N > 0)
                N <= N - 1;
            else 
                N <= 0;
            end
        end
    end

    //FSM block
    always@(*)begin
        case (state)
            INIT:begin
                if(flick)
                    next_state = ON_0_TO_15; 
                else
                    next_state = INIT;
            end

            ON_0_TO_15: begin
                if(operation == UP)
                    next_state = ON_0_TO_15;
                else begin
                    next_state = OFF_15_TO_5;
                end
            end

            OFF_15_TO_5: begin
                if(operation == DOWN || operation == KICKBACK)
                    next_state = OFF_15_TO_5;
                else
                    next_state = ON_5_TO_10;
            end

            ON_5_TO_10: begin
                if(operation == UP)
                    next_state = ON_5_TO_10;
                else
                    next_state = OFF_10_TO_0;
            end

            OFF_10_TO_0: begin
                if(operation == DOWN || operation == KICKBACK)
                    next_state = OFF_10_TO_0;
                else
                    next_state = ON_0_TO_5;
            end

            ON_0_TO_5: begin
                if(operation == UP)
                    next_state = ON_0_TO_5;
                else
                    next_state = OFF_5_TO_0;
            end

            OFF_5_TO_0:begin
                if(operation == DOWN)
                    next_state = OFF_5_TO_0;
                else
                    next_state = INIT;
            end
            default: begin
                next_state = INIT;
            end
        endcase
    end

    //Decode
    always @(*) begin
        led = 16'b0;
        if(state != INIT)begin
        for (i = 0; i < 16 ; i = i + 1) begin
                if((N >=0) && (N < 16) && (i <= N))
                    led[i] = 1'b1;
                else
                    led[i] = 1'b0;
            end
        end
    end
endmodule

//UP: N = N + 1
//DOWN: N = N - 1
//KICKBACK: N = N - 1 
