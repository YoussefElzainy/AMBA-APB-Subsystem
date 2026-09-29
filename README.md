# AMBA APB Subsystem

A simple **AMBA APB4-based subsystem** designed using **Verilog HDL**.

## Overview

This project implements an **AMBA APB4 subsystem** that demonstrates how an APB master communicates with multiple APB slave devices through address-based slave selection.

The design includes an APB interface, slave selection logic, and multiple peripheral slaves.

## Architecture

The subsystem consists of:

* **APB Master Interface**
* **APB Address Decoder**
* **APB Slave Select Logic**
* **Register Slave**
* **RAM / Memory Slave**
* **APB Read Data Multiplexer**

The address decoder determines which slave should respond to each APB transaction.

## APB Transactions

The design supports the basic APB transfer sequence:

1. **IDLE** – No transfer is active.
2. **SETUP** – `PSEL` is asserted and the transfer address/control signals are established.
3. **ACCESS** – `PENABLE` is asserted and the selected slave completes the transfer.

Both **read** and **write** transactions are supported.

## Main Features

* AMBA **APB4** interface
* Multiple APB slaves
* Address-based slave selection
* Read and write transactions
* Register-based peripheral
* RAM / Memory peripheral
* APB read-data multiplexing
* Synthesizable Verilog RTL

## Verification

The design is verified through simulation using testbench-based APB transactions.

Verification focuses on:

* APB read transactions
* APB write transactions
* Correct slave selection
* Register access
* Memory access
* APB transfer sequencing

## Tools

* **Verilog HDL**
* **QuestaSim**

## Project Structure

```text
AMBA-APB-Subsystem/
│
├── RTL/
│   ├── APB Master
│   ├── APB Decoder
│   ├── APB Slaves
│   └── Supporting Modules
│
├── Testbench/
│   └── APB Testbench
│
└── README.md
```

## Objective

The main objective of this project is to understand and implement the **AMBA APB protocol** at RTL level while gaining practical experience with:

* Bus protocols
* RTL architecture
* Address decoding
* Memory-mapped peripherals
* Verilog design
* Simulation and verification
