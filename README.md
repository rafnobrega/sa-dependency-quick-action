# SA Dependency Quick Action

A Salesforce Quick Action that automatically creates **Finish-to-Start (Complex Work)** dependencies between all Service Appointments under a Work Order.

## What It Does

- Queries all Service Appointments under a Work Order (via WOLIs)
- Orders them by `EarliestStartTime ASC`
- Creates `FSL__Time_Dependency__c` records chaining them sequentially (SA1 → SA2 → SA3 → ...)
- Splits into chains of **max 5 SAs** to avoid the FSL GetCandidates limitation
- **Deletes and recreates** dependencies if they already exist

## Components

| File | Description |
|------|-------------|
| `SADependencyController.cls` | Apex controller — queries SAs, manages dependency chain creation |
| `SADependencyControllerTest.cls` | Test class with 100% coverage |
| `createSADependencies/` | LWC Quick Action — confirmation screen with spinner and result display |

## Prerequisites

- Salesforce Field Service (FSL) managed package installed
- `FSL__Time_Dependency__c` object available in the org

## Deployment

```bash
sf project deploy start --source-dir force-app --target-org <your-org-alias>
```

## Setup After Deployment

1. **Create a Quick Action** on the WorkOrder object:
   - Object: `WorkOrder`
   - Action Type: `Lightning Web Component`
   - Lightning Web Component: `c:createSADependencies`
   - Label: `Create SA Dependencies`
2. **Add the Quick Action** to the Work Order page layout (Mobile & Lightning Actions section)
3. Navigate to a Work Order with 2+ Service Appointments and run the action

## How Chain Splitting Works

FSL's GetCandidates API has a limit of **5 Service Appointments per dependency chain**. This component automatically splits larger groups:

| SAs | Chains | Dependencies |
|-----|--------|-------------|
| 4   | 1      | 3           |
| 5   | 1      | 4           |
| 7   | 2 (5+2)| 5           |
| 10  | 2 (5+5)| 8           |
