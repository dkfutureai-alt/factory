# FactoryOS Business Flows

## Core Operational Chain

Purchase -> Raw Material -> Inventory -> Production -> Quality -> Finished Goods -> Warehouse -> Sales -> Dispatch -> Vehicle/Driver -> Delivery -> Customer -> Payment / Return.

## Workforce Flow

Employee -> Check In -> Shift/Task -> Work Entries -> Break/Resume -> Check Out -> Attendance Review -> Payroll/HR export (future).

## Delivery Flow

Sales/transfer demand -> dispatch planning -> stock reservation -> vehicle + driver assignment -> loading -> gate-out -> in-transit updates -> customer proof -> delivery completion -> empty/returnable pickup where applicable -> warehouse receipt.

## Cylinder / Returnable Asset Flow

Filled asset -> warehouse -> dispatch -> customer -> empty obligation -> reverse pickup -> inspection -> return to available/maintenance state -> refill.

This flow is essential for oxygen/gas clients but will be implemented as a generic returnable-asset model so other factories can reuse it.

## Maintenance Flow

Asset/vehicle/machine -> issue -> work order -> assignment -> parts/labor -> downtime -> verification -> close -> history/report.

## Required State-Machine Rule

Business states cannot be arbitrary free text. Every module must define allowed states and allowed transitions, validate them in the backend, and record actor/time for critical transitions.
