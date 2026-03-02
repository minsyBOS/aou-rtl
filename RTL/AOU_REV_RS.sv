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
//  Module     : AOU_REV_RS
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_REV_RS #(
    parameter  DATA_WIDTH = 16
)
(
    input                    I_CLK          ,
    input                    I_RESETN       ,

    input                    I_SVALID       ,
    output                   O_SREADY       ,
    input  [DATA_WIDTH -1:0] I_SDATA        ,

    output                   O_MVALID       ,
    input                    I_MREADY       ,
    output [DATA_WIDTH -1:0] O_MDATA
);

  logic [DATA_WIDTH -1:0]     r_payload;     
  logic                       w_payload_buf_en;       
  logic                       r_payload_buf_full_en;  
  logic                       r_payload_buf_full;     

  assign w_payload_buf_en = (I_SVALID & ~r_payload_buf_full & ~I_MREADY);

  always_ff @(posedge I_CLK or negedge I_RESETN) begin
    if (~I_RESETN)
      r_payload <= 'd0;
    else if (w_payload_buf_en)
      r_payload <= I_SDATA;
  end
  
  assign r_payload_buf_full_en = (w_payload_buf_en | I_MREADY);
  
  always_ff @(posedge I_CLK or negedge I_RESETN) begin
    if (~I_RESETN)
      r_payload_buf_full <= 1'b0;
    else if (r_payload_buf_full_en)
      r_payload_buf_full <= w_payload_buf_en;
  end
  
  assign O_SREADY = ~r_payload_buf_full;
  assign O_MVALID = (I_SVALID | r_payload_buf_full);

  assign O_MDATA = r_payload_buf_full ? r_payload : I_SDATA;

endmodule 
