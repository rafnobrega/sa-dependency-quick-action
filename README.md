# SA Dependency Quick Action

Salesforce Quick Actions for managing **Finish-to-Start (Complex Work)** dependencies between Service Appointments under a Work Order — create and delete them directly from the Work Order record page.

## What It Does

### Create SA Dependencies (LWC Quick Action)

- Queries Service Appointments parented directly to the Work Order
- Optionally includes SAs parented to Work Order Line Items (via checkbox toggle)
- Orders them by `EarliestStartTime ASC`
- Creates `FSL__Time_Dependency__c` records chaining them sequentially (SA1 → SA2 → SA3 → ...)
- Splits into chains of **max 5 SAs** to avoid the FSL GetCandidates limitation
- **Deletes and recreates** dependencies if they already exist

### Delete SA Dependencies (LWC Quick Action)

- Deletes all `FSL__Time_Dependency__c` records linked to the Work Order's Service Appointments
- Same WOLI toggle to control scope
- Confirmation screen before deleting

### Delete SA Dependencies (Screen Flow)

- Standalone flow — pick any Work Order via lookup and delete its SA dependencies
- Available via Setup > Flows > RN SFS Delete SA Dependencies > Run

## Components

| File | Description |
|------|-------------|
| `SADependencyController.cls` | Apex controller — `createDependencies` and `deleteDependencies` methods |
| `SADependencyControllerTest.cls` | Test class — WO-level SAs, WOLI SAs, combined, multi-chain, delete & recreate |
| `createSADependencies/` | LWC Quick Action — create dependencies with WOLI toggle |
| `deleteSADependencies/` | LWC Quick Action — delete dependencies with WOLI toggle |
| `WorkOrder.Create_SA_Dependencies.quickAction-meta.xml` | Quick Action — wires create LWC to Work Order |
| `WorkOrder.Delete_SA_Dependencies.quickAction-meta.xml` | Quick Action — wires delete LWC to Work Order |
| `RN_SFS_Delete_SA_Dependencies.flow-meta.xml` | Screen Flow — standalone delete via WO lookup |

## Prerequisites

- Salesforce Field Service (FSL) managed package installed
- `FSL__Time_Dependency__c` object available in the org

## Deployment

1. **Clone the repo:**
   ```bash
   git clone https://github.com/rafnobrega/sa-dependency-quick-action.git
   cd sa-dependency-quick-action
   ```

2. **Authorize your org** (skip if already connected):
   ```bash
   sf org login web --set-default --alias <your-org-alias>
   ```

3. **Deploy to your org:**
   ```bash
   sf project deploy start --source-dir force-app --target-org <your-org-alias>
   ```

## Setup After Deployment

### Quick Actions (Create & Delete)

1. **Add both Quick Actions** to the Work Order Lightning Record Page (Highlights Panel or Mobile & Lightning Actions section)
2. Navigate to a Work Order with 2+ Service Appointments and run the action

### SA Scope

Both actions default to Service Appointments parented directly to the Work Order. Check **"Include Service Appointments from Work Order Line Items"** to also include SAs parented to WOLIs.

### Delete SA Dependencies (Screen Flow)

The flow deploys as **Active** — no additional setup required. To run it:

- **Setup > Flows > RN SFS Delete SA Dependencies > Run**, or
- Add it to a **Utility Bar**, **Lightning page**, or **custom button** for quick access

## FSL Field Mapping Gotcha

The `FSL__Time_Dependency__c` field names are counterintuitive. In the Complex Work UI, "First Appointment" and "Second Appointment" do **not** mean predecessor and successor:

| Field | UI Label | Actual Role |
|-------|----------|-------------|
| `FSL__Service_Appointment_1__c` | First Appointment | **Successor** — the SA that *waits* |
| `FSL__Service_Appointment_2__c` | Second Appointment | **Predecessor** — the SA that *goes first* |

For a **Start After Finish** dependency: *SA1 starts after SA2 finishes.*

This component handles the mapping correctly — just be aware of it if you're inspecting or creating dependency records manually.

## How Chain Splitting Works

FSL's GetCandidates API has a limit of **5 Service Appointments per dependency chain**. This component automatically splits larger groups:

| SAs | Chains | Dependencies |
|-----|--------|-------------|
| 4   | 1      | 3           |
| 5   | 1      | 4           |
| 7   | 2 (5+2)| 5           |
| 10  | 2 (5+5)| 8           |
