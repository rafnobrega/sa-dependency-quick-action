# SA Dependency Quick Action

Salesforce tools for managing **Finish-to-Start (Complex Work)** dependencies between Service Appointments under a Work Order — create them automatically via Quick Action, and delete them via Screen Flow.

## What It Does

### Create SA Dependencies (LWC Quick Action)

- Queries all Service Appointments under a Work Order (via WOLIs)
- Orders them by `EarliestStartTime ASC`
- Creates `FSL__Time_Dependency__c` records chaining them sequentially (SA1 → SA2 → SA3 → ...)
- Splits into chains of **max 5 SAs** to avoid the FSL GetCandidates limitation
- **Deletes and recreates** dependencies if they already exist

### Delete SA Dependencies (Screen Flow)

- Pick any Work Order via lookup
- Finds all `FSL__Time_Dependency__c` records linked to that Work Order's Service Appointments
- Confirmation screen before deleting
- Error handling with fault message display

## Components

| File | Description |
|------|-------------|
| `SADependencyController.cls` | Apex controller — queries SAs, manages dependency chain creation |
| `SADependencyControllerTest.cls` | Test class with 100% coverage |
| `createSADependencies/` | LWC Quick Action — confirmation screen with spinner and result display |
| `RN_SFS_Delete_SA_Dependencies.flow-meta.xml` | Screen Flow — select a Work Order and delete all its SA dependencies |

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

### Create SA Dependencies (Quick Action)

1. **Create a Quick Action** on the WorkOrder object:
   - Object: `WorkOrder`
   - Action Type: `Lightning Web Component`
   - Lightning Web Component: `c:createSADependencies`
   - Label: `Create SA Dependencies`
2. **Add the Quick Action** to the Work Order page layout (Mobile & Lightning Actions section)
3. Navigate to a Work Order with 2+ Service Appointments and run the action

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
