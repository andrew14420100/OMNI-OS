// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Strutture e algoritmi condivisi fra OMNI Boot e il kernel OMNI.
//!
//! Tutto il codice è `no_std`, senza allocazione e senza `unsafe`: si prova sul computer di
//! build con `cargo test -p omni-comune` (parser ELF, SHA-256, bitmap dei frame, ACPI, font,
//! pacchetto iniziale, ABI delle chiamate di sistema, caricatore dei programmi).
#![no_std]
#![forbid(unsafe_code)]

#[cfg(test)]
extern crate std;

pub mod abi;
pub mod acpi;
pub mod bitmap;
pub mod bootinfo;
pub mod caricatore;
pub mod elf;
pub mod font;
pub mod pacchetto;
pub mod sha256;
