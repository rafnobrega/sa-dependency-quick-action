public with sharing class SADependencyController {

    @AuraEnabled
    public static String createDependencies(Id workOrderId, Boolean includeWoliSAs) {
        Set<Id> parentIds = new Set<Id>{ workOrderId };

        if (includeWoliSAs == true) {
            for (WorkOrderLineItem woli : [SELECT Id FROM WorkOrderLineItem WHERE WorkOrderId = :workOrderId]) {
                parentIds.add(woli.Id);
            }
        }

        List<ServiceAppointment> sas = [
            SELECT Id, AppointmentNumber, EarliestStartTime
            FROM ServiceAppointment
            WHERE ParentRecordId IN :parentIds
            ORDER BY EarliestStartTime ASC
        ];

        if (sas.size() < 2) {
            return 'Need at least 2 Service Appointments to create dependencies. Found: ' + sas.size();
        }

        Set<Id> saIds = new Set<Id>();
        for (ServiceAppointment sa : sas) {
            saIds.add(sa.Id);
        }

        List<FSL__Time_Dependency__c> existingDeps = [
            SELECT Id FROM FSL__Time_Dependency__c
            WHERE FSL__Service_Appointment_1__c IN :saIds
            OR FSL__Service_Appointment_2__c IN :saIds
        ];
        if (!existingDeps.isEmpty()) {
            delete existingDeps;
        }

        Integer chainSize = 5;
        Integer totalChains = (Integer) Math.ceil((Decimal) sas.size() / chainSize);
        List<FSL__Time_Dependency__c> newDeps = new List<FSL__Time_Dependency__c>();

        for (Integer c = 0; c < totalChains; c++) {
            Integer startIdx = c * chainSize;
            Integer endIdx = Math.min(startIdx + chainSize, sas.size());
            Id rootSaId = sas[startIdx].Id;

            for (Integer i = startIdx; i < endIdx - 1; i++) {
                newDeps.add(new FSL__Time_Dependency__c(
                    FSL__Service_Appointment_1__c = sas[i + 1].Id,
                    FSL__Service_Appointment_2__c = sas[i].Id,
                    FSL__Dependency__c = 'Start After Finish',
                    FSL__Root_Service_Appointment__c = rootSaId,
                    FSL__Same_Resource__c = false
                ));
            }
        }

        insert newDeps;

        return 'Created ' + newDeps.size() + ' dependencies across ' + sas.size() + ' Service Appointments in ' + totalChains + ' chain(s) of up to ' + chainSize + '.';
    }

    @AuraEnabled
    public static String deleteDependencies(Id workOrderId, Boolean includeWoliSAs) {
        Set<Id> parentIds = new Set<Id>{ workOrderId };

        if (includeWoliSAs == true) {
            for (WorkOrderLineItem woli : [SELECT Id FROM WorkOrderLineItem WHERE WorkOrderId = :workOrderId]) {
                parentIds.add(woli.Id);
            }
        }

        Set<Id> saIds = new Set<Id>();
        for (ServiceAppointment sa : [SELECT Id FROM ServiceAppointment WHERE ParentRecordId IN :parentIds]) {
            saIds.add(sa.Id);
        }

        if (saIds.isEmpty()) {
            return 'No Service Appointments found on this Work Order.';
        }

        List<FSL__Time_Dependency__c> deps = [
            SELECT Id FROM FSL__Time_Dependency__c
            WHERE FSL__Service_Appointment_1__c IN :saIds
            OR FSL__Service_Appointment_2__c IN :saIds
        ];

        if (deps.isEmpty()) {
            return 'No dependencies found to delete.';
        }

        Integer count = deps.size();
        delete deps;

        return 'Deleted ' + count + ' dependencies across ' + saIds.size() + ' Service Appointments.';
    }
}
