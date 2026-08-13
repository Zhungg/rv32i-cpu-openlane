`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/pkg/rv32i_pmp_pkg.sv
//
// RISC-V standard Physical Memory Protection (PMP) types and definitions.

package rv32i_pmp_pkg;

    localparam int unsigned PMP_ENTRIES = 4;

    localparam logic [1:0] PMP_A_OFF   = 2'b00;
    localparam logic [1:0] PMP_A_TOR   = 2'b01;
    localparam logic [1:0] PMP_A_NA4   = 2'b10;
    localparam logic [1:0] PMP_A_NAPOT = 2'b11;

    typedef enum logic [1:0] {
        PMP_ACC_READ    = 2'd0,
        PMP_ACC_WRITE   = 2'd1,
        PMP_ACC_EXECUTE = 2'd2
    } pmp_access_type_e;

    typedef struct packed {
        logic       l;  // Lock bit
        logic [1:0] res;
        logic [1:0] a;  // Address matching mode
        logic       x;  // Execute permission
        logic       w;  // Write permission
        logic       r;  // Read permission
    } pmp_cfg_t;

    // Privilege modes
    typedef enum logic [1:0] {
        PRIV_USER       = 2'b00,
        PRIV_SUPERVISOR = 2'b01,
        PRIV_RESERVED   = 2'b10,
        PRIV_MACHINE    = 2'b11
    } priv_mode_e;

endpackage
