// *****************************************************************************
// SPDX-License-Identifier: Apache-2.0
// *****************************************************************************
//  Copyright (c) 2026 BOS Semiconductors
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// *****************************************************************************
//
//  Module     : AOU_FIFO_RP
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_FIFO_RP
#(
    parameter   AXI_PEER_DIE_MAX_DATA_WD    = 1024,
    localparam  AXI_MAX_STRB_WD             = AXI_PEER_DIE_MAX_DATA_WD/8,
    parameter   AXI_ID_WD                   = 10,

    parameter   AW_AR_FIFO_WIDTH            = 10 + 64 + 8 + 3 + 1 + 4 + 3 + 4,
    parameter   B_FIFO_WIDTH                = AXI_ID_WD + 2,
    parameter   R_FIFO_EXT_DATA_WIDTH       = AXI_ID_WD + 2 + 1,
                
    parameter   AW_FIFO_DEPTH               = 44,
    parameter   AR_FIFO_DEPTH               = 44,
    parameter   W_FIFO_DEPTH                = 88,
    parameter   R_FIFO_DEPTH                = 88,
    parameter   B_FIFO_DEPTH                = 44,
    
    parameter   MAX_WR_REQ_COUNT            = 4,
    parameter   MAX_RD_REQ_COUNT            = 4, 
    parameter   MAX_WR_DATA_COUNT           = 2,
    parameter   MAX_RD_DATA_COUNT           = 2,
    parameter   MAX_WR_RESP_COUNT           = 12
)
(
    input                                                       I_CLK,
    input                                                       I_RESETN,

    input       [MAX_WR_REQ_COUNT -1:0]                         I_WR_REQ_FIFO_SVALID,
    input       [MAX_WR_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]   I_WR_REQ_FIFO_SDATA,
    input                                                       I_WR_REQ_FIFO_MREADY,
    output      [AW_AR_FIFO_WIDTH -1:0]                         O_WR_REQ_FIFO_MDATA,
    output                                                      O_WR_REQ_FIFO_MVALID,

    input       [3:0]                                           I_WR_DATA_FIFO_SVALID,
    input       [3:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]             I_WR_DATA_FIFO_SDATA,
    input       [3:0][AXI_MAX_STRB_WD -1:0]                     I_WR_DATA_FIFO_STRB,
    input       [3:0]                                           I_WR_DATA_FIFO_WDATAF,

    input                                                       I_WR_DATA_FIFO_MREADY,
    output      [AXI_PEER_DIE_MAX_DATA_WD-1:0]                  O_WR_DATA_FIFO_MDATA,
    output      [AXI_MAX_STRB_WD-1:0]                           O_WR_DATA_FIFO_MSTRB,
    output      [1:0]                                           O_WR_DATA_FIFO_MDLEN,
    output                                                      O_WR_DATA_FIFO_WDATAF,
    output                                                      O_WR_DATA_FIFO_MVALID,

    input       [MAX_RD_REQ_COUNT -1:0]                         I_RD_REQ_FIFO_SVALID,
    input       [MAX_RD_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]   I_RD_REQ_FIFO_SDATA,
    
    input                                                       I_RD_REQ_FIFO_MREADY,
    output      [AW_AR_FIFO_WIDTH -1:0]                         O_RD_REQ_FIFO_MDATA,
    output                                                      O_RD_REQ_FIFO_MVALID,
    
    input       [3:0]                                           I_RD_DATA_FIFO_SVALID,
    input       [3:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]             I_RD_DATA_FIFO_SDATA,
    input       [3:0][R_FIFO_EXT_DATA_WIDTH -1:0]               I_RD_DATA_FIFO_EXT_SDATA,

    input                                                       I_RD_DATA_FIFO_MREADY,
    output      [AXI_PEER_DIE_MAX_DATA_WD-1:0]                  O_RD_DATA_FIFO_MDATA,
    output      [R_FIFO_EXT_DATA_WIDTH -1:0]                    O_RD_DATA_FIFO_EXT_MDATA,
    output      [1:0]                                           O_RD_DATA_FIFO_MDLEN,
    output                                                      O_RD_DATA_FIFO_MVALID,

    input       [MAX_WR_RESP_COUNT -1:0]                        I_WR_RESP_FIFO_SVALID,
    input       [MAX_WR_RESP_COUNT -1:0][B_FIFO_WIDTH-1:0]      I_WR_RESP_FIFO_SDATA,
    
    input                                                       I_WR_RESP_FIFO_MREADY,
    output      [B_FIFO_WIDTH-1:0]                              O_WR_RESP_FIFO_MDATA,
    output                                                      O_WR_RESP_FIFO_MVALID
);

    logic w_b_fwd_rs_ready;
    logic [MAX_WR_RESP_COUNT -1:0] w_wr_resp_fwd_rs_mvalid;
    logic w_b_fwd_rs_valid;
    logic [MAX_WR_RESP_COUNT -1:0][B_FIFO_WIDTH-1:0] w_wr_resp_fwd_rs_mdata;

    AOU_SYNC_FIFO_NS1M #(
        .FIFO_WIDTH                 ( AW_AR_FIFO_WIDTH                  ),
        .FIFO_DEPTH                 ( AW_FIFO_DEPTH                     ),
        .ICH_CNT                    ( MAX_WR_REQ_COUNT                  ),
        .ALWAYS_READY               ( 1                                 )
    ) u_aou_rx_aw_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
        // write transaction
        .I_SVALID                   ( I_WR_REQ_FIFO_SVALID              ),
        .I_SDATA                    ( I_WR_REQ_FIFO_SDATA               ),
        .O_SREADY                   (                                   ),
        // read transaction
        .I_MREADY                   ( I_WR_REQ_FIFO_MREADY              ),
        .O_MDATA                    ( O_WR_REQ_FIFO_MDATA               ), 
        .O_MVALID                   ( O_WR_REQ_FIFO_MVALID              ),
    
        .O_S_EMPTY_CNT              (                                   ),
        .O_M_DATA_CNT               (                                   )
    );
    
    AOU_DATA_W_FIFO_NS1M #(
        .AXI_PEER_DIE_MAX_DATA_WD   ( AXI_PEER_DIE_MAX_DATA_WD          ),
        .FIFO_DEPTH                 ( W_FIFO_DEPTH                      ),
        .ICH_CNT                    ( 4                                 ),
        .ALWAYS_READY               ( 1                                 )
    ) u_aou_rx_w_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
    
        // write transaction
        .I_SVALID                   ( I_WR_DATA_FIFO_SVALID             ),
        .I_SDATA                    ( I_WR_DATA_FIFO_SDATA              ),
        .I_SDATA_STRB               ( I_WR_DATA_FIFO_STRB               ),
        .I_SDATA_WDATAF             ( I_WR_DATA_FIFO_WDATAF             ),
        .O_SREADY                   (                                   ),
        
        // read transaction
        .I_MREADY                   ( I_WR_DATA_FIFO_MREADY             ),
        .O_MDATA                    ( O_WR_DATA_FIFO_MDATA              ),
        .O_MDATA_STRB               ( O_WR_DATA_FIFO_MSTRB              ),
        .O_MDLEN                    ( O_WR_DATA_FIFO_MDLEN              ),
        .O_MDATA_WDATAF             ( O_WR_DATA_FIFO_WDATAF             ),
        .O_MVALID                   ( O_WR_DATA_FIFO_MVALID             )
    );
    
    AOU_SYNC_FIFO_NS1M #(
        .FIFO_WIDTH                 ( AW_AR_FIFO_WIDTH                  ),                   
        .FIFO_DEPTH                 ( AR_FIFO_DEPTH                     ),
        .ICH_CNT                    ( MAX_RD_REQ_COUNT                  ),
        .ALWAYS_READY               ( 1                                 )
    ) u_aou_rx_ar_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
        // write transaction
        .I_SVALID                   ( I_RD_REQ_FIFO_SVALID              ),
        .I_SDATA                    ( I_RD_REQ_FIFO_SDATA               ),
        .O_SREADY                   (                                   ),
        // read transaction
        .I_MREADY                   ( I_RD_REQ_FIFO_MREADY              ),
        .O_MDATA                    ( O_RD_REQ_FIFO_MDATA               ),
        .O_MVALID                   ( O_RD_REQ_FIFO_MVALID              ),

        .O_S_EMPTY_CNT              (                                   ),
        .O_M_DATA_CNT               (                                   )
    );

    AOU_DATA_R_FIFO_NS1M #(
        .AXI_PEER_DIE_MAX_DATA_WD   ( AXI_PEER_DIE_MAX_DATA_WD          ),
        .EXT_FIFO_WD                ( AXI_ID_WD + 2 + 1                 ), 
        .FIFO_DEPTH                 ( R_FIFO_DEPTH                      ),
        .ICH_CNT                    ( 4                                 ),
        .ALWAYS_READY               ( 1                                 )
    ) u_aou_rx_r_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
        // write transaction
        .I_SVALID                   ( I_RD_DATA_FIFO_SVALID             ),
        .I_SDATA                    ( I_RD_DATA_FIFO_SDATA              ),
        .I_EXT_SDATA                ( I_RD_DATA_FIFO_EXT_SDATA          ),
        .O_SREADY                   (                                   ),
        // read transaction 
        .I_MREADY                   ( I_RD_DATA_FIFO_MREADY             ),
        .O_MDATA                    ( O_RD_DATA_FIFO_MDATA              ), 
        .O_EXT_MDATA                ( O_RD_DATA_FIFO_EXT_MDATA          ),
        .O_MDLEN                    ( O_RD_DATA_FIFO_MDLEN              ),
        .O_MVALID                   ( O_RD_DATA_FIFO_MVALID             )
    );
 
    AOU_FWD_RS #(
        .DATA_WIDTH         ( MAX_WR_RESP_COUNT*(B_FIFO_WIDTH+1) )
    ) u_aou_rx_b_fwd_rs
    (
        .I_CLK              ( I_CLK                     ),                                          
        .I_RESETN           ( I_RESETN                  ),                
    
        .I_SVALID           ( |I_WR_RESP_FIFO_SVALID    ),            
        .I_SDATA            ( {I_WR_RESP_FIFO_SVALID, I_WR_RESP_FIFO_SDATA}),
        .O_SREADY           (                           ),
    
        .I_MREADY           ( w_b_fwd_rs_ready          ), 
        .O_MDATA            ( {w_wr_resp_fwd_rs_mvalid, w_wr_resp_fwd_rs_mdata}),        
        .O_MVALID           ( w_b_fwd_rs_valid          )                                
    );


    AOU_SYNC_FIFO_NS1M #(
        .FIFO_WIDTH                 ( B_FIFO_WIDTH                  ),
        .FIFO_DEPTH                 ( B_FIFO_DEPTH                  ),
        .ICH_CNT                    ( MAX_WR_RESP_COUNT             ),
        .ALWAYS_READY               ( 1                             )
    ) u_aou_rx_b_fifo_rp0
    (
        .I_CLK                      ( I_CLK                         ),
        .I_RESETN                   ( I_RESETN                      ),
        // write transaction
        .I_SVALID                   ( w_wr_resp_fwd_rs_mvalid & {MAX_WR_RESP_COUNT{w_b_fwd_rs_valid}}),
        .I_SDATA                    ( w_wr_resp_fwd_rs_mdata        ),
        .O_SREADY                   ( w_b_fwd_rs_ready              ),
        // read transaction
        .I_MREADY                   ( I_WR_RESP_FIFO_MREADY         ),
        .O_MDATA                    ( O_WR_RESP_FIFO_MDATA          ), 
        .O_MVALID                   ( O_WR_RESP_FIFO_MVALID         ),
    
        .O_S_EMPTY_CNT              (                               ),
        .O_M_DATA_CNT               (                               )
    );

endmodule  
