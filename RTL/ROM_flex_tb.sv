
module ROM_flex_tb ();


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// function log2   y = 0                if x=0
//                 y = floor(log2(x-1)) if x>0
// if a memory has x items, then y is its address bit width
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function automatic logic [31:0] log2(input logic [63:0] x);
    logic [31:0] y = 0;
    logic [63:0] xt = (x>0) ? (x-1) : 0;
    while (xt > 0) begin
        xt >>= 1;
        y ++;
    end
    return y;
endfunction


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// parameters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
localparam DEPTH  = 1025;
localparam BITS_D = 36 + 36 + 18 + 9;
localparam BITS_A = log2(DEPTH);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// signals
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg clka='0  , clkb='0  ;
always #4 clka = ~clka;
always #5 clkb = ~clkb;

reg  [BITS_A-1:0] addra_r='0 , addrb_r='0 ;
reg  [BITS_A-1:0] addra='0 , addrb='0 ;
wire [BITS_D-1:0] rdataa, rdatab;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// random ROM initial values
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
localparam ROMVALUE_COUNT = 71;
localparam [BITS_D-1:0] ROMVALUE_ARRAY [ROMVALUE_COUNT] = {128'h698c912d1a87212068ad83e89034cdac,128'hb281906996d16830ea8d75d7204c5762,128'haecb122c2db8b331d6d261c4d7758aa6,128'h5866846773304e07e336d2759f54d566,128'ha6a9c053ece7afcc8c92f48b857eabec,128'he2fc65322186c8a58b6acc93e9d27368,128'hd82ba0a03af0d1b6d66378f88daed824,128'hca1137e22d948faac93491c4e5d86608,128'hdb02def40d0ad0e16683fd4d4ce06672,128'ha6a609e21a8693000cff1f8ca5474664,128'ha2daf3881b8028d5e6a9f2e0de9c7a2a,128'h585acc1f9824ad67b3f7980264fcc132,128'h648e723d735d54b7296f1c339772241d,128'hd4784cbbd6989942a3546ec33d5622c5,128'h90afbd9a439f35e95d5c39c00cb33b4d,128'hd8a004d7441933ab5ac52b542fb01deb,128'h10036b6c19b1917d33c47ca30f168309,128'hefc0acb86e78389f26ac0dfbc88607ab,128'hf9612ea7e3e4bcb3e88e0e4578aec57e,128'h28fd66636e81845479824d309729c6e7,128'h9e9b9b63cead15d70c1f0647ba00140b,128'h1b8b2b23ba95d6eeb5cfb834b2d2b376,128'h0262725044256d0b50931d4086d1f715,128'h68ecdc4380c4c37314837dbe682b238b,128'h30065ab2cde98d1001966b351531b896,128'hc1890c05158c3fdfac951ad3aa0c7166,128'h99886254bb8b2f9fb64734e3851390c9,128'h8d549152fe5df8e0972ef186e5f83176,128'h8e92de90dc04710ae0c9da529d1dcbce,128'h79122fd13134c9fce7cc29a7bcbab638,128'h4a06515d3d4b2e457156a42a57cdbf6e,128'h376205bf9643a4911b8ea096fb392c6b,128'h0015d48d8261c43b49990503538b154d,128'hbf7844e906054074b1dd9ebbe133ae45,128'h28c9c3ada90500ac87c303b5543bde63,128'hb7684c7841f30580077ae3b886d4ba27,128'h17053314ec2075d257f91ef328b0a7b9,128'h535fd827aff1ecaaaee4a534ca33e32c,128'hcc45e9ecb2e6560396c427d4c030a5f0,128'h9b4038f26f05b063f3ae1ad757025051,128'h8d13ecc15ad3adc7e2b6e74d00584798,128'h06552ac675c60e7829272a6db9e3580d,128'h2e85b7f96a3eade09990f04e07a03c61,128'hd5e62244dbe119b1addf42038eccecd0,128'hb61eea6024b698c25636c4caad245051,128'h2ceb8cf07f1778570e33bdcddf4c1a11,128'h3b93a024b76ade6dae642aae9730b1d7,128'h9a278be73802ea87a295c0a245b9498d,128'hac136d7e501663acf943c4fb55f9e01b,128'h97667e9f32aa20f58d21c506ff6648b1,128'h1041ca7b32ffb98148aacd74bd5d339b,128'hcf79c2aa378cb51823d4e4af62bade2d,128'h84fc46e1c9befb6c5bc07ceb138f9530,128'h2fee27b581a84f0e360bb0d8da89a22c,128'h0dd2503e0b077b4d53ca905ff5a4b0ab,128'h82877645a686f0d9e59f4da12a1eadd6,128'h3fa149f19434377cd64a5a918c5f947b,128'h3547a9c3ae2cbdb2c34e6c2f501b7e9f,128'hcbd07d90d3d91f2f1de71191228ccce1,128'ha84e08b2a2bf4a7906d9a512a707aeb7,128'h7b054a458f06896145779c245100f425,128'hde925172014b9175e1f46631d89214b3,128'he473d78d2cc112139c0aee0b32bfa438,128'h15f55575b209a1d1c9cf2e67cc91fb52,128'h88df5d07a686eb5e186c7b7d6dec60bf,128'h626178d3cd852051b58ceb383ffbf9de,128'hf635af712150b0f1fa92cd40523a056f,128'h9eeb42a9d425681679439454e5cdf859,128'h32459bbbaf2ecd00c0693c0aaaec1283,128'h0c85a0597aff9eec1a2bdbb0e0e5e869,128'h88ce56c281190b08dcfce819fc9dab67};


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ROM instance
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
ROM_flex #(
    // FPGA low layer BRAM structure specific configuration
    .BITS_AU                          ( 10                          ),
    .BITS_DU                          ( 18                          ),
    // width and depth configuration
    .DEPTH                            ( DEPTH                       ),
    .BITS_D                           ( BITS_D                      ),
    // ROM values configuration
    .ROMVALUE_COUNT                   ( ROMVALUE_COUNT              ),
    .ROMVALUE_ARRAY                   ( ROMVALUE_ARRAY              )
) ROM_flex_i (
    // PORTA
    .clka                             ( clka                        ),
    .addra                            ( addra                       ),
    .rdataa                           ( rdataa                      ),
    // PORTB
    .clkb                             ( clkb                        ),
    .addrb                            ( addrb                       ),
    .rdatab                           ( rdatab                      )
);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// address generate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
initial begin
    repeat (10) @ (posedge clka);
    repeat (10) @ (posedge clkb);
    fork
        begin
            for(int i=0; i<DEPTH*2; i++) begin
                @ (posedge clka) addra <= (addra+1<DEPTH) ? (addra+1) : 0;
            end
        end
        begin
            for(int i=0; i<DEPTH*2; i++) begin
                @ (posedge clkb) addrb <= (addrb+1<DEPTH) ? (addrb+1) : 0;
            end
        end
    join
    repeat (10) @ (posedge clka);
    repeat (10) @ (posedge clkb);
    $stop;
end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// readout check
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @ (posedge clka) addra_r <= addra;
always @ (posedge clkb) addrb_r <= addrb;

wire err_a = rdataa != ROMVALUE_ARRAY[addra_r % ROMVALUE_COUNT] ;
wire err_b = rdatab != ROMVALUE_ARRAY[addrb_r % ROMVALUE_COUNT] ;


endmodule

