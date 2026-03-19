@IsTest
private class SADependencyControllerTest {

    @TestSetup
    static void setup() {
        WorkOrder wo = new WorkOrder(Subject = 'Dependency Test WO');
        insert wo;

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        for (Integer i = 0; i < 4; i++) {
            wolis.add(new WorkOrderLineItem(
                WorkOrderId = wo.Id,
                Duration = 2.0,
                DurationType = 'Hours'
            ));
        }
        insert wolis;

        List<ServiceAppointment> sas = new List<ServiceAppointment>();
        for (Integer i = 0; i < wolis.size(); i++) {
            sas.add(new ServiceAppointment(
                ParentRecordId = wolis[i].Id,
                EarliestStartTime = DateTime.now().addDays(i * 3),
                DueDate = DateTime.now().addDays((i * 3) + 2)
            ));
        }
        insert sas;
    }

    @IsTest
    static void testCreateDependencies() {
        WorkOrder wo = [SELECT Id FROM WorkOrder WHERE Subject = 'Dependency Test WO' LIMIT 1];

        Test.startTest();
        String result = SADependencyController.createDependencies(wo.Id);
        Test.stopTest();

        System.assert(result.contains('Created 3 dependencies'), 'Should create 3 dependencies for 4 SAs. Got: ' + result);
        System.assert(result.contains('1 chain(s)'), 'Should be 1 chain for 4 SAs. Got: ' + result);

        List<FSL__Time_Dependency__c> deps = [
            SELECT FSL__Service_Appointment_1__c, FSL__Service_Appointment_2__c,
                   FSL__Dependency__c, FSL__Root_Service_Appointment__c
            FROM FSL__Time_Dependency__c
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(3, deps.size(), 'Should have 3 dependency records');

        for (FSL__Time_Dependency__c dep : deps) {
            System.assertEquals('Start After Finish', dep.FSL__Dependency__c, 'Dependency type should be Start After Finish');
        }

        Id rootId = deps[0].FSL__Root_Service_Appointment__c;
        for (FSL__Time_Dependency__c dep : deps) {
            System.assertEquals(rootId, dep.FSL__Root_Service_Appointment__c, 'All deps in chain should share the same root SA');
        }
    }

    @IsTest
    static void testLessThanTwoSAs() {
        WorkOrder wo = new WorkOrder(Subject = 'Single SA WO');
        insert wo;
        WorkOrderLineItem woli = new WorkOrderLineItem(
            WorkOrderId = wo.Id,
            Duration = 1.0,
            DurationType = 'Hours'
        );
        insert woli;
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = woli.Id,
            EarliestStartTime = DateTime.now(),
            DueDate = DateTime.now().addDays(1)
        );
        insert sa;

        Test.startTest();
        String result = SADependencyController.createDependencies(wo.Id);
        Test.stopTest();

        System.assert(result.contains('Need at least 2'), 'Should return insufficient SAs message. Got: ' + result);
    }

    @IsTest
    static void testDeleteAndRecreate() {
        WorkOrder wo = [SELECT Id FROM WorkOrder WHERE Subject = 'Dependency Test WO' LIMIT 1];

        SADependencyController.createDependencies(wo.Id);

        List<FSL__Time_Dependency__c> firstRun = [SELECT Id FROM FSL__Time_Dependency__c];
        System.assertEquals(3, firstRun.size(), 'First run should create 3 deps');

        Test.startTest();
        String result = SADependencyController.createDependencies(wo.Id);
        Test.stopTest();

        List<FSL__Time_Dependency__c> secondRun = [SELECT Id FROM FSL__Time_Dependency__c];
        System.assertEquals(3, secondRun.size(), 'Second run should still have exactly 3 deps');
        System.assert(result.contains('Created 3 dependencies'), 'Should recreate 3 dependencies. Got: ' + result);
    }

    @IsTest
    static void testRootSAIsFirst() {
        WorkOrder wo = [SELECT Id FROM WorkOrder WHERE Subject = 'Dependency Test WO' LIMIT 1];

        Test.startTest();
        SADependencyController.createDependencies(wo.Id);
        Test.stopTest();

        ServiceAppointment firstSA = [
            SELECT Id FROM ServiceAppointment
            WHERE ParentRecordId IN (
                SELECT Id FROM WorkOrderLineItem WHERE WorkOrderId = :wo.Id
            )
            ORDER BY EarliestStartTime ASC
            LIMIT 1
        ];

        List<FSL__Time_Dependency__c> deps = [
            SELECT FSL__Root_Service_Appointment__c FROM FSL__Time_Dependency__c
        ];

        for (FSL__Time_Dependency__c dep : deps) {
            System.assertEquals(firstSA.Id, dep.FSL__Root_Service_Appointment__c,
                'Root SA should be the first SA by EarliestStartTime');
        }
    }

    @IsTest
    static void testMultiChainSplit() {
        WorkOrder wo = new WorkOrder(Subject = 'Multi Chain WO');
        insert wo;

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        for (Integer i = 0; i < 7; i++) {
            wolis.add(new WorkOrderLineItem(
                WorkOrderId = wo.Id,
                Duration = 1.0,
                DurationType = 'Hours'
            ));
        }
        insert wolis;

        List<ServiceAppointment> sas = new List<ServiceAppointment>();
        for (Integer i = 0; i < 7; i++) {
            sas.add(new ServiceAppointment(
                ParentRecordId = wolis[i].Id,
                EarliestStartTime = DateTime.now().addDays(i),
                DueDate = DateTime.now().addDays(i + 1)
            ));
        }
        insert sas;

        Test.startTest();
        String result = SADependencyController.createDependencies(wo.Id);
        Test.stopTest();

        System.assert(result.contains('2 chain(s)'), 'Should split into 2 chains. Got: ' + result);

        List<FSL__Time_Dependency__c> deps = [
            SELECT FSL__Root_Service_Appointment__c
            FROM FSL__Time_Dependency__c
        ];
        // 7 SAs = chain of 5 (4 deps) + chain of 2 (1 dep) = 5 total deps
        System.assertEquals(5, deps.size(), 'Should have 5 dependency records for 7 SAs');

        Set<Id> rootIds = new Set<Id>();
        for (FSL__Time_Dependency__c dep : deps) {
            rootIds.add(dep.FSL__Root_Service_Appointment__c);
        }
        System.assertEquals(2, rootIds.size(), 'Should have 2 different root SAs for 2 chains');
    }
}
