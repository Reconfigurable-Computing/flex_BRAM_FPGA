
module BRAM_flex_tb ();

//////////////////////////////////////////////////////////////////////////////
// function log2   y = 0                if x=0
//                 y = floor(log2(x-1)) if x>0
// if a memory has x items, then y is its address bit width
//////////////////////////////////////////////////////////////////////////////
function automatic logic [31:0] log2(input logic [63:0] x);
    logic [31:0] y = 0;
    logic [63:0] xt = (x>0) ? (x-1) : 0;
    while (xt > 0) begin
        xt >>= 1;
        y ++;
    end
    return y;
endfunction


localparam DEPTH  = 5130;
localparam BITS_D = 20;
localparam BITS_A = log2(DEPTH);


reg               clka='0  , clkb='0  ;
always #4 clka = ~clka;
always #5 clkb = ~clkb;

reg  [BITS_A-1:0] addra='0 , addrb='0 ;
wire [BITS_D-1:0] rdataa, rdatab;


BRAM_flex #(
    // FPGA low layer BRAM structure specific configuration
    .BITS_AU                          ( 10                          ),
    .BITS_DU                          ( 18                          ),
    // width and depth configuration
    .DEPTH                            ( DEPTH                       ),
    .BITS_D                           ( BITS_D                      ),
    // functional configuration
    .PORTA_ENABLE_WRITE               ( "FALSE"                     ),
    .PORTB_ENABLE_WRITE               ( "FALSE"                     ),
    .PORTA_READ_FIRST                 ( "TRUE"                      ),
    .PORTB_READ_FIRST                 ( "TRUE"                      ),
    // initial values configuration
    .INITVALUE_COUNT                  ( 6                           ),
    .INITVALUE_ARRAY                  ( '{2,4,6,7,1,3}              ),
    .INITVALUE_DEFAULT                ( 10                          ),
    // random initial value (only for debug)
    .TESTPATTERN                      ( 1                           )
) BRAM_flex_i (
    // PORTA
    .clka                             ( clka                        ),
    .addra                            ( addra                       ),
    .rdataa                           ( rdataa                      ),
    .wena                             ( '0                          ),
    .wdataa                           ( '0                          ),
    // PORTB
    .clkb                             ( clkb                        ),
    .addrb                            ( addrb                       ),
    .rdatab                           ( rdatab                      ),
    .wenb                             ( '0                          ),
    .wdatab                           ( '0                          )
);


initial begin
    #100
    fork
        begin
            for(int i=0; i<DEPTH*3; i++) begin
                @ (posedge clka) addra <= addra + 1;
            end
        end
        begin
            for(int i=0; i<DEPTH*2; i++) begin
                @ (posedge clkb) addrb <= addrb + 1;
            end
        end
    join
    #100
    $stop;
end

endmodule

