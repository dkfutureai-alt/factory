# FactoryOS Business Flows

## 1. Purchase to Inventory

Purchase Request
→ Approval
→ Purchase Order
→ Goods Receipt
→ Batch/Serial Capture
→ Stock Transaction
→ Inventory Balance Update
→ Supplier Invoice/Return as applicable

Rules:
- Goods cannot increase stock without a receipt-backed stock transaction.
- Receipt quantity cannot silently exceed PO tolerance.
- Batch/serial requirements come from item configuration.

## 2. Inventory to Production

Production Order
→ Material Requirement
→ Material Reservation/Request
→ Material Issue
→ Raw Material Stock Transaction
→ Production Batch Start

Rules:
- Insufficient stock blocks issue unless an authorized exception exists.
- Every issue remains traceable to production order/batch.

## 3. Production to Quality to Finished Goods

Production Batch
→ Material Consumption
→ Output/Wastage/Rejection
→ Quality Check
→ Pass / Hold / Fail
→ Finished Goods Receipt
→ Finished Goods Stock Transaction

Rules:
- A QC-controlled product cannot become available stock before release.
- Partial completion is supported.
- Rejected quantity and reason are stored.

## 4. Batch Traceability

Raw Material Batch
→ Stock Receipt
→ Production Consumption
→ Production Batch
→ Finished Goods Batch
→ Dispatch
→ Delivery
→ Customer

Traceability must work both forward and backward.

## 5. Sales to Delivery

Quotation
→ Sales Order
→ Pick/Pack
→ Dispatch Order
→ Vehicle + Driver Assignment
→ Trip
→ Delivery
→ POD
→ Invoice
→ Payment / Outstanding / Return

Rules:
- Delivery quantity cannot exceed authorized dispatch quantity without adjustment.
- Partial delivery and failed delivery are explicit statuses.
- POD belongs to a delivery event and records actor/time/evidence.

## 6. Vehicle / Driver Duty

Driver Login
→ Assigned Vehicle
→ Pre-trip Inspection
→ Start Duty
→ Start Trip
→ Fuel / Breakdown / Delivery Events
→ Return Vehicle
→ End Odometer
→ End Duty
→ Mileage/Utilization Calculation

Rules:
- One active driver assignment per vehicle unless configured otherwise.
- Odometer cannot decrease.
- Fuel distance and efficiency are calculated from verified odometer entries.

## 7. Attendance / HR

Employee
→ Assigned Department/Shift
→ Check-In
→ Break
→ Check-Out
→ Work Duration
→ Attendance Classification
→ Overtime/Late Rules

Leave:
Employee Request
→ Manager/HR Approval
→ Leave Balance Update
→ Calendar/Attendance Classification

Rules:
- Duplicate attendance for the same shift/day is prevented.
- Checkout cannot precede check-in.
- Leave without available balance follows configured policy instead of silently succeeding.

## 8. Asset Maintenance

Breakdown / Preventive Schedule
→ Maintenance Job
→ Technician Assignment
→ Inspection
→ Spare Part Issue
→ Inventory Transaction
→ Repair/Action
→ Downtime + Cost
→ Root Cause
→ Asset Status Update
→ Maintenance Report

Rules:
- Spares consumption is ledger-backed.
- Asset state and downtime are updated consistently when a job closes.

## 9. Approval Flow

Draft
→ Submitted
→ Manager Review
→ Approved
or
→ Rejected

Applied to configurable objects such as leave, purchase requests, stock adjustments, overtime, expenses, maintenance and special dispatch.

## 10. Cross-Module End-to-End Test

Create Purchase Order
→ Receive Raw Material
→ Verify Inventory Increased
→ Create Production Order
→ Issue Raw Material
→ Verify Raw Stock Reduced
→ Start/Complete Production
→ Execute QC
→ Verify Finished Stock Added
→ Create Sales Order
→ Dispatch
→ Assign Vehicle/Driver
→ Run Trip
→ Complete Delivery/POD
→ Verify Inventory/Fulfillment
→ Verify Invoice/Payment State

This journey is the primary FactoryOS operational acceptance test.