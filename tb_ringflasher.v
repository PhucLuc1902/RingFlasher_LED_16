`timescale 1ps/1ps

module tb_ringflasher;

    reg clk;
    reg rst_n;
    reg flick;
    wire [15:0] led;

    ringflasher dut (
        .clk(clk),
        .rst_n(rst_n),
        .flick(flick),
        .led(led)
    );

    // Clock generation

    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 10ps period
    end

    // Dump waveform

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_ringflasher.clk);
        $dumpvars(0, tb_ringflasher.rst_n);
        $dumpvars(0, tb_ringflasher.flick);
        $dumpvars(0, tb_ringflasher.led);
        $dumpvars(0, tb_ringflasher.dut.N);
        $dumpvars(0, tb_ringflasher.dut.state);
        $dumpvars(0, tb_ringflasher.dut.operation);
    end

    // Helpers

    task wait_posedge;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
        end
    endtask

    task pulse_flick_1clk;
        begin
            flick = 1'b1;
            @(posedge clk);
            #1;
            flick = 1'b0;
        end
    endtask

    task do_reset;
        begin
            rst_n = 1'b0;
            flick = 1'b0;
            wait_posedge(2);
            #1;
            rst_n = 1'b1;
        end
    endtask

    function [15:0] expected_led_from_n;
        input integer n;
        integer j;
        begin
            expected_led_from_n = 16'b0;
            if (n >= 0 && n < 16) begin
                for (j = 0; j < 16; j = j + 1) begin
                    if (j <= n)
                        expected_led_from_n[j] = 1'b1;
                    else
                        expected_led_from_n[j] = 1'b0;
                end
            end
        end
    endfunction

    task check_led;
        input [15:0] exp;
        input [255:0] msg;
        begin
            #1;
            if (led !== exp) begin
                $display("FAIL @%0t : %s | expected=%h got=%h", $time, msg, exp, led);
                $stop;
            end
            else begin
                $display("PASS @%0t : %s | led=%h", $time, msg, led);
            end
        end
    endtask

    task check_state;
        input [6:0] exp_state;
        input [255:0] msg;
        begin
            #1;
            if (dut.state !== exp_state) begin
                $display("FAIL @%0t : %s | expected state=%b got=%b", $time, msg, exp_state, dut.state);
                $stop;
            end
            else begin
                $display("PASS @%0t : %s | state=%b", $time, msg, dut.state);
            end
        end
    endtask

    // Main test

    initial begin
        rst_n = 1'b1;
        flick = 1'b0;

        // CASE 1: Reset -> INIT -> all OFF

        do_reset();
        check_state(dut.INIT, "after reset, state = INIT");
        check_led(16'h0000, "after reset, led all OFF");

        // CASE 2: Stay in INIT while flick=0

        wait_posedge(3);
        check_state(dut.INIT, "stay INIT when flick=0");
        check_led(16'h0000, "stay OFF when flick=0");

        // CASE 3: Start operating when flick is ACTIVE
 
        pulse_flick_1clk();
        wait_posedge(1);
        check_state(dut.ON_0_TO_15, "leave INIT and enter ON_0_TO_15");

        // code hiện tại của bạn sẽ bắt đầu với N=0 rồi tăng dần
        check_led(expected_led_from_n(dut.N), "LED pattern matches N in ON_0_TO_15");

        // CASE 4: Reach top of ON_0_TO_15

        while (dut.state == dut.ON_0_TO_15)
            @(posedge clk);

        #1;
        check_state(dut.OFF_15_TO_5, "transition ON_0_TO_15 -> OFF_15_TO_5");
        check_led(expected_led_from_n(dut.N), "LED pattern valid in OFF_15_TO_5");

        // CASE 5: Normal OFF_15_TO_5 without kickback

        while (dut.state == dut.OFF_15_TO_5 && dut.N > 5)
            @(posedge clk);

        @(posedge clk);
        #1;
        check_state(dut.ON_5_TO_10, "transition OFF_15_TO_5 -> ON_5_TO_10 (normal)");
        check_led(expected_led_from_n(dut.N), "LED pattern valid in ON_5_TO_10");

        // CASE 6: Reach OFF_10_TO_0 normally

        while (dut.state == dut.ON_5_TO_10)
            @(posedge clk);

        #1;
        check_state(dut.OFF_10_TO_0, "transition ON_5_TO_10 -> OFF_10_TO_0");
        check_led(expected_led_from_n(dut.N), "LED pattern valid in OFF_10_TO_0");

        // CASE 7: Normal OFF_10_TO_0 without kickback

        while (dut.state == dut.OFF_10_TO_0 && dut.N > 0)
            @(posedge clk);

        @(posedge clk);
        #1;
        check_state(dut.ON_0_TO_5, "transition OFF_10_TO_0 -> ON_0_TO_5 (normal)");
        check_led(expected_led_from_n(dut.N), "LED pattern valid in ON_0_TO_5");

        // CASE 8: Reach OFF_5_TO_0 normally

        while (dut.state == dut.ON_0_TO_5)
            @(posedge clk);

        #1;
        check_state(dut.OFF_5_TO_0, "transition ON_0_TO_5 -> OFF_5_TO_0");
        check_led(expected_led_from_n(dut.N), "LED pattern valid in OFF_5_TO_0");

        // CASE 9: Final OFF state returns to INIT
        // no kickback allowed here

        while (dut.state == dut.OFF_5_TO_0 && dut.N > 0)
            @(posedge clk);

        @(posedge clk);
        #1;
        check_state(dut.INIT, "transition OFF_5_TO_0 -> INIT");
        check_led(16'h0000, "back to all OFF at INIT");

        // KICKBACK TEST 1: kickback at N=5 in OFF_15_TO_5

        $display("------ KICKBACK TEST AT 5 ------");
        do_reset();
        pulse_flick_1clk();

        while (dut.state != dut.OFF_15_TO_5)
            @(posedge clk);

        while (!(dut.state == dut.OFF_15_TO_5 && dut.N == 5))
            @(posedge clk);

        flick = 1'b1;
        @(posedge clk);
        #1;
        flick = 1'b0;

        // do code của bạn giữ state khi KICKBACK
        check_state(dut.OFF_15_TO_5, "kickback at 5 repeats OFF_15_TO_5");
        check_led(expected_led_from_n(dut.N), "LED pattern valid after kickback at 5");

        // KICKBACK TEST 2: kickback at N=0 in OFF_10_TO_0

        $display("------ KICKBACK TEST AT 0 ------");
        do_reset();
        pulse_flick_1clk();

        while (dut.state != dut.OFF_10_TO_0)
            @(posedge clk);

        while (!(dut.state == dut.OFF_10_TO_0 && dut.N == 0))
            @(posedge clk);

        flick = 1'b1;
        @(posedge clk);
        #1;
        flick = 1'b0;

        check_state(dut.OFF_10_TO_0, "kickback at 0 repeats OFF_10_TO_0");
        check_led(expected_led_from_n(dut.N), "LED pattern valid after kickback at 0");

        // FINAL STATE NO KICKBACK
    
        $display("------ FINAL STATE NO KICKBACK ------");
        do_reset();
        pulse_flick_1clk();

        while (dut.state != dut.OFF_5_TO_0)
            @(posedge clk);

        while (!(dut.state == dut.OFF_5_TO_0 && dut.N == 0))
            @(posedge clk);

        flick = 1'b1;
        @(posedge clk);
        #1;
        flick = 1'b0;

        check_state(dut.INIT, "OFF_5_TO_0 is final state, no kickback, must return INIT");
        check_led(16'h0000, "final state returns to all OFF");

        $display("==========================================");
        $display("ALL TESTS PASSED");
        $display("==========================================");
        $finish;
    end

endmodule