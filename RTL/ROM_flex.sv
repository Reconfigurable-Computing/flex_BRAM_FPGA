
//-------------------------------------------------------------------------------------------------------------------------------------------
// Module   : ROM_flex
// Copyright: WangXuan
// Type     : synthesizable, IP's top
// Standard : SystemVerilog 2005 (IEEE1800-2005)
// Function : flexible ROM wrapper.
//            Divide the reg array to match the BRAM width and depth in specific FPGA.
//            Achieve efficient BRAM utilization.
//-------------------------------------------------------------------------------------------------------------------------------------------

module ROM_flex #(
    // FPGA low layer BRAM structure specific configuration
    parameter              BITS_AU          = 10,
    parameter              BITS_DU          = 18,
    // width and depth configuration
    parameter              DEPTH            = 4096,
    parameter              BITS_D           = 16,
    // ROM values configuration
    parameter              ROMVALUE_COUNT   = DEPTH,
    parameter [BITS_D-1:0] ROMVALUE_ARRAY [ROMVALUE_COUNT] = '{ROMVALUE_COUNT{'1}}
) (
//  PORTA  , PORTB
    clka   , clkb   ,
    addra  , addrb  ,
    rdataa , rdatab
);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// function log2   y = 0              if x=0
//                 y = floor(log2(x)) if x>0
// if a memory has x items, then y is its address bit width
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function automatic logic [31:0] log2(input logic [31:0] x);
    logic [31:0] y = 0;
    logic [31:0] xt = x;
    while (xt > 0) begin
        xt >>= 1;
        y ++;
    end
    return (y>0) ? (y-1) : 0;
endfunction


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// function log2m1 y = 0                if x=0
//                 y = floor(log2(x-1)) if x>0
// if a memory has x items, then y is its address bit width
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function automatic logic [31:0] log2m1(input logic [31:0] x);
    logic [31:0] y = 0;
    logic [31:0] xt = (x>0) ? (x-1) : 0;
    while (xt > 0) begin
        xt >>= 1;
        y ++;
    end
    return y;
endfunction


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// local parameters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
localparam DEPTHX     = (DEPTH > 2) ? DEPTH : 2 ;                                                           //                                              min : 2
localparam BITS_DX    = (BITS_D > 1) ? BITS_D : 1 ;                                                         //                                              min : 1

localparam DEPTHU     = ( 1 << BITS_AU );                                                                   // the depth of a block unit                    min : ?
localparam DEPTHR     = ((DEPTHX % DEPTHU) == 0) ? DEPTHU : (DEPTHX % DEPTHU) > 2 ? (DEPTHX % DEPTHU) : 2;  // the depth of the remain block on depth       min : 2
localparam BLOCK_CNT  = ( DEPTHX + DEPTHU - 1 ) / DEPTHU;                                                   // block count                                  min : 1

localparam BITS_A     = log2m1(DEPTHX);                                                                     // address bit width                            min : 1
localparam BITS_AH    = (BITS_A > BITS_AU) ? (BITS_A - BITS_AU) : 1;                                        // address bit width high : to select block     min : 1

localparam BITS_DTMP  = ( (BITS_DX % BITS_DU) <= (BITS_DU / 2) ) ? (BITS_DX % BITS_DU) : 0 ;
localparam BITS_DH    = (BITS_DTMP > 0) ? BITS_DTMP : BITS_DX;                                              // data bit high : can be fold                  min : 1
localparam BITS_DL    = BITS_DX - BITS_DH;                                                                  // data bit low  : needn't to be fold           min : 0

localparam BITS_AF    = log2(BITS_DU / BITS_DH);                                                            // 0:no-fold   1:2-fold   2:4-fold   ...        min : 0
localparam BITS_AFH   = (BITS_AH>BITS_AF) ? (BITS_AH-BITS_AF) : 0;                                          //                                              min : 0
localparam RATIO_F    = (1 << BITS_AF);                                                                     // fold ratio                                   min : 1
localparam RATIO_FR   = ((BLOCK_CNT % RATIO_F) > 0) ? (BLOCK_CNT % RATIO_F) : RATIO_F ;                     // fold ratio of the remain fold block          min : 1
localparam BLOCKF_CNT = (BLOCK_CNT + RATIO_F - 1) / RATIO_F ;                                               // fold block count                             min : 1
localparam BITS_DF    = BITS_DH * RATIO_F;                                                                  // fold data bit width                          min : 1
localparam DEPTHFR    = (RATIO_FR > 1) ? DEPTHU : DEPTHR;                                                   // depth of the remain fold block               min : 2



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// module interface
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
input  wire               clka  , clkb  ;
input  wire [ BITS_A-1:0] addra , addrb ;
output wire [BITS_DX-1:0] rdataa, rdatab;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// address split
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [BITS_AH-1:0] addra_h = (BITS_AH)'(addra >> BITS_AU);
wire [BITS_AH-1:0] addrb_h = (BITS_AH)'(addrb >> BITS_AU);
wire [BITS_AU-1:0] addra_u = (BITS_AU)'(addra);
wire [BITS_AU-1:0] addrb_u = (BITS_AU)'(addrb);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// address beat to next cycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg  [BITS_AH-1:0] addra_h_r;
reg  [BITS_AH-1:0] addrb_h_r;

always @ (posedge clka) addra_h_r <= addra_h;
always @ (posedge clkb) addrb_h_r <= addrb_h;

wire [BITS_AF-1:0] addra_f_r;
wire [BITS_AF-1:0] addrb_f_r;
generate if(BITS_AF > 0) begin
    assign addra_f_r = (BITS_AF)'(addra_h_r);
    assign addrb_f_r = (BITS_AF)'(addrb_h_r);
end endgenerate

wire [BITS_AFH-1:0] addra_fh_r;
wire [BITS_AFH-1:0] addrb_fh_r;
generate if(BITS_AFH > 0) begin
    assign addra_fh_r = (BITS_AFH)'(addra_h_r >> BITS_AF);
    assign addrb_fh_r = (BITS_AFH)'(addrb_h_r >> BITS_AF);
end endgenerate


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// read out and selection signals
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [BITS_DH-1:0] rdataa_h [BLOCKF_CNT];
wire [BITS_DH-1:0] rdatab_h [BLOCKF_CNT];
reg  [BITS_DL-1:0] rdataa_l [BLOCK_CNT];
reg  [BITS_DL-1:0] rdatab_l [BLOCK_CNT];

generate if(BITS_DL > 0) begin
    if(BITS_AFH > 0) begin
        assign rdataa = {rdataa_h[addra_fh_r], rdataa_l[addra_h_r]};
        assign rdatab = {rdatab_h[addrb_fh_r], rdatab_l[addrb_h_r]};
    end else begin
        assign rdataa = {rdataa_h[0], rdataa_l[addra_h_r]};
        assign rdatab = {rdatab_h[0], rdatab_l[addrb_h_r]};
    end
end else begin
    if(BITS_AFH > 0) begin
        assign rdataa = rdataa_h[addra_fh_r];
        assign rdatab = rdatab_h[addrb_fh_r];
    end else begin
        assign rdataa = rdataa_h[0];
        assign rdatab = rdatab_h[0];
    end
end endgenerate


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
generate genvar ib, io, i_f;
    for( ib=0 ; ib<BLOCKF_CNT ; ib++ ) begin : loop_ib                       // for all fold block
        localparam DEPTHF_C  = (ib < (BLOCKF_CNT-1)) ? DEPTHU  : DEPTHFR ;   // current fold block depth             min : 2
        localparam RATIO_F_C = (ib < (BLOCKF_CNT-1)) ? RATIO_F : RATIO_FR;   // current fold block fold ratio        min : 1
        
        wire [BITS_DH*RATIO_F_C-1:0] RAMF [DEPTHF_C];
        initial $display("----------------------------- user info : deploy wire [%d:0] RAMF [%d]", BITS_DH*RATIO_F_C-1, DEPTHF_C);    // only for show info
        
        reg  [BITS_DF-1:0] rdataa_f;
        reg  [BITS_DF-1:0] rdatab_f;
        always @ (posedge clka)  rdataa_f <= (BITS_DF)'( RAMF[addra_u] );
        always @ (posedge clkb)  rdatab_f <= (BITS_DF)'( RAMF[addrb_u] );
        
        if(BITS_AF > 0) begin
            assign rdataa_h[ib] = rdataa_f[ addra_f_r*BITS_DH +: BITS_DH ];
            assign rdatab_h[ib] = rdatab_f[ addrb_f_r*BITS_DH +: BITS_DH ];
        end else begin
            assign rdataa_h[ib] = rdataa_f[                 0 +: BITS_DH ];
            assign rdatab_h[ib] = rdatab_f[                 0 +: BITS_DH ];
        end
        
        for( i_f=0 ; i_f<RATIO_F_C ; i_f++ ) begin : loop_i_f
            for( io=0 ; io<DEPTHF_C ; io++ ) begin : loop_io
                assign RAMF[io][ i_f*BITS_DH +: BITS_DH ] = (BITS_DH)'( ( (BITS_DX)'( ROMVALUE_ARRAY[((ib*RATIO_F+i_f)*DEPTHU+io) % ROMVALUE_COUNT] ) ) >> BITS_DL ) ;
                // equal to: (Avoid generating too many localparams)
                //localparam LOGIC_ADDR = ((ib*RATIO_F+i_f)*DEPTHU+io) ;
                //localparam [BITS_DX-1:0] VALUE  = ROMVALUE_ARRAY[LOGIC_ADDR % ROMVALUE_COUNT];
                //assign RAMF[io][ i_f*BITS_DH +: BITS_DH ] = (BITS_DH)'( VALUE >> BITS_DL ) ;
            end
        end
    end
endgenerate


generate genvar jb, jo;
    if( BITS_DL > 0 ) begin
        for( jb=0 ; jb<BLOCK_CNT ; jb++ ) begin : loop_jb                    // for all block
            localparam DEPTH_C = (jb < (BLOCK_CNT-1)) ? DEPTHU : DEPTHR ;    // current RAM block depth                  min : 2
            
            wire [BITS_DL-1:0] RAML [DEPTH_C];
            initial $display("----------------------------- user info : deploy wire [%d:0] RAML [%d]", BITS_DL-1, DEPTH_C);    // only for show info
            
            always @ (posedge clka)  rdataa_l[jb] <= RAML[addra_u];
            always @ (posedge clkb)  rdatab_l[jb] <= RAML[addrb_u];
            
            for( jo=0 ; jo<DEPTH_C ; jo++ ) begin : loop_jo
                assign RAML[jo] = (BITS_DL)'( ROMVALUE_ARRAY[(jb*DEPTHU+jo) % ROMVALUE_COUNT] );
                // equal to: (Avoid generating too many localparams)
                //localparam LOGIC_ADDR = (jb*DEPTHU+jo) ;
                //localparam [BITS_DX-1:0] VALUE  = ( ROMVALUE_ARRAY[LOGIC_ADDR % ROMVALUE_COUNT] );
                //assign RAML[jo] = (BITS_DL)'(VALUE);
            end
        end
    end
endgenerate


endmodule
