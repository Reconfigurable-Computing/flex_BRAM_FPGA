
//--------------------------------------------------------------------------------------------------------
// Module   : BRAM_flex
// Copyright: WangXuan
// Type     : synthesizable, IP's top
// Standard : SystemVerilog 2005 (IEEE1800-2005)
// Function : flexible block RAM wrapper.
//            Divide the reg array to match the BRAM width and depth in specific FPGA.
//            Achieve efficient BRAM utilization.
//--------------------------------------------------------------------------------------------------------

module BRAM_flex_v0 #(
    // FPGA low layer BRAM structure specific configuration
    parameter              BITS_AU                           = 10,
    parameter              BITS_DU                           = 18,
    // width and depth configuration
    parameter              DEPTH                             = 4096,
    parameter              BITS_D                            = 18,
    // functional configuration
    parameter              PORTA_ENABLE_WRITE                = "TRUE",    // "TRUE" or "FALSE"
    parameter              PORTB_ENABLE_WRITE                = "TRUE",    // "TRUE" or "FALSE"
    parameter              PORTA_READ_FIRST                  = "TRUE",    // "TRUE" or "FALSE"
    parameter              PORTB_READ_FIRST                  = "TRUE",    // "TRUE" or "FALSE"
    // initial values configuration
    parameter              INITVALUE_COUNT                   = 4,
    parameter [BITS_D-1:0] INITVALUE_ARRAY [INITVALUE_COUNT] = '{INITVALUE_COUNT{'0}},
    parameter [BITS_D-1:0] INITVALUE_DEFAULT                 = '0
) (
//  PORTA  , PORTB
    clka   , clkb   ,
    addra  , addrb  ,
    rdataa , rdatab ,
    wena   , wenb   ,
    wdataa , wdatab
);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// function log2   y = 0                if x=0
//                 y = floor(log2(x-1)) if x>0
// if a memory has x items, then y is its address bit width
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function automatic logic [31:0] log2(input logic [63:0] x);
    logic [31:0] y = 0;
    logic [63:0] xt = (x>0) ? (x-1) : 0;
    while (xt > 0) begin
        xt >>= 1;
        y ++;
    end
    return y;
endfunction


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// local parameters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
localparam DEPTHU    = ( 1 << BITS_AU );                                        // the depth of a RAM block unit
localparam DEPTHT_R  = ((DEPTH % DEPTHU) == 0) ? DEPTHU : (DEPTH % DEPTHU);
localparam DEPTHT    = (DEPTHT_R>2) ? DEPTHT_R : 2;                             // the depth of the last RAM block on depth
localparam BLOCK_CNT = ( DEPTH + DEPTHU - 1 ) / DEPTHU;                         // the RAM block count on depth

localparam BITS_A  = log2(DEPTH);
localparam BITS_AH = (BITS_A > BITS_AU) ? (BITS_A - BITS_AU) : 1;
localparam BITS_AT = log2(DEPTHT);

localparam BITS_DH = ( (BITS_D % BITS_DU) <= (BITS_DU / 2) ) ? (BITS_D % BITS_DU) : 0 ;
localparam BITS_DL = BITS_D - BITS_DH;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// module interface
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
input  wire              clka  , clkb  ;
input  wire [BITS_A-1:0] addra , addrb ;
output wire [BITS_D-1:0] rdataa, rdatab;
input  wire              wena  , wenb  ;
input  wire [BITS_D-1:0] wdataa, wdatab;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// address split
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [BITS_AH-1:0] addra_h = (BITS_AH)'(addra >> BITS_AU);
wire [BITS_AH-1:0] addrb_h = (BITS_AH)'(addrb >> BITS_AU);
wire [BITS_AU-1:0] addra_u = (BITS_AU)'(addra);
wire [BITS_AU-1:0] addrb_u = (BITS_AU)'(addrb);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RAM read out and selection signals
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [ BITS_D-1:0] rdataa_r [BLOCK_CNT];                         // read-out value of every RAM block
wire [ BITS_D-1:0] rdatab_r [BLOCK_CNT];                         // read-out value of every RAM block

reg  [BITS_AH-1:0] addra_h_r, addrb_h_r;

always @ (posedge clka) addra_h_r <= addra_h;
always @ (posedge clkb) addrb_h_r <= addrb_h;

wire [ BITS_D-1:0] rdataa_s = rdataa_r[addra_h_r];
wire [ BITS_D-1:0] rdatab_s = rdatab_r[addrb_h_r];


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PORTA read
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
generate if(PORTA_ENABLE_WRITE != "TRUE" || PORTA_READ_FIRST == "TRUE") begin
    assign rdataa = rdataa_s;
end else begin
    reg                wena_r  ;
    reg  [BITS_D-1:0]  wdataa_r;
    always @ (posedge clka) wena_r <= wena;
    always @ (posedge clka) wdataa_r <= wdataa;
    assign rdataa = wena_r ? wdataa_r : rdataa_s;
end endgenerate


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PORTB read
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
generate if(PORTB_ENABLE_WRITE != "TRUE" || PORTB_READ_FIRST == "TRUE") begin
    assign rdatab = rdatab_s;
end else begin
    reg                wenb_r  ;
    reg  [BITS_D-1:0]  wdatab_r;
    always @ (posedge clkb) wenb_r <= wenb;
    always @ (posedge clkb) wdatab_r <= wdatab;
    assign rdatab = wenb_r ? wdatab_r : rdatab_s;
end endgenerate


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PORTA & PORTB write
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
generate genvar ii, jj, kk;
    for( ii=0 ; ii<BLOCK_CNT ; ii++ ) begin : loop_ii
        
        wire wena_block = wena && (addra_h==(BITS_AH)'(ii)) ;
        wire wenb_block = wenb && (addrb_h==(BITS_AH)'(ii)) ;
        
        localparam DEPTHB = ( ii < (BLOCK_CNT-1) ) ? DEPTHU : DEPTHT ;    // current RAM block depth
        
        wire [BITS_D-1:0] rdataa_out, rdatab_out ;
        
        assign rdataa_r[ii] = rdataa_out;
        assign rdatab_r[ii] = rdatab_out;
        
        if(BITS_DH > 0) begin
            reg [BITS_DH-1:0] RAMH [DEPTHB];
            
            if(PORTA_ENABLE_WRITE == "TRUE")  always @ (posedge clka)  if(wena_block)  RAMH[addra_u] <= (BITS_DH)'(wdataa >> BITS_DL);
            if(PORTB_ENABLE_WRITE == "TRUE")  always @ (posedge clkb)  if(wenb_block)  RAMH[addrb_u] <= (BITS_DH)'(wdatab >> BITS_DL);
            
            reg [BITS_DH-1:0] rdataa_h_out, rdatab_h_out;
            always @ (posedge clka)  rdataa_h_out <= RAMH[addra_u];
            always @ (posedge clkb)  rdatab_h_out <= RAMH[addrb_u];
            assign rdataa_out[BITS_D-1:BITS_DL] = rdataa_h_out;
            assign rdatab_out[BITS_D-1:BITS_DL] = rdatab_h_out;
            
            for( jj=0 ; jj<DEPTHB ; jj++ ) begin : loop_jj
                localparam [BITS_D-1:0] VALUE = (DEPTHU*ii+jj < INITVALUE_COUNT) ? INITVALUE_ARRAY[DEPTHU*ii+jj] : INITVALUE_DEFAULT;
                initial RAMH[jj] = (BITS_DH)'(VALUE >> BITS_DL) ;
            end
        end
        
        if(BITS_DL > 0) begin
            reg [BITS_DL-1:0] RAML [DEPTHB];
            
            if(PORTA_ENABLE_WRITE == "TRUE")  always @ (posedge clka)  if(wena_block)  RAML[addra_u] <= (BITS_DL)'(wdataa);
            if(PORTB_ENABLE_WRITE == "TRUE")  always @ (posedge clkb)  if(wenb_block)  RAML[addrb_u] <= (BITS_DL)'(wdatab);
            
            reg [BITS_DL-1:0] rdataa_l_out, rdatab_l_out;
            always @ (posedge clka)  rdataa_l_out <= RAML[addra_u];
            always @ (posedge clkb)  rdatab_l_out <= RAML[addrb_u];
            assign rdataa_out[BITS_DL-1:0] = rdataa_l_out;
            assign rdatab_out[BITS_DL-1:0] = rdatab_l_out;
            
            for( kk=0 ; kk<DEPTHB ; kk++ ) begin : loop_kk
                localparam [BITS_D-1:0] VALUE = (DEPTHU*ii+kk < INITVALUE_COUNT) ? INITVALUE_ARRAY[DEPTHU*ii+kk] : INITVALUE_DEFAULT;
                initial RAML[kk] = (BITS_DL)'(VALUE) ;
            end
        end
        
    end
endgenerate


endmodule
