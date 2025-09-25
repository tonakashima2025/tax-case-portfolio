@isTest
private class TaxCaseTaskGeneratorTest {
    
    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }
    
    @isTest
    static void testTaskGeneration() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Tax_Case__c taxCase = new Tax_Case__c(
            Account__c = acc.Id,
            Tax_Type__c = '法人税',
            Filing_Deadline__c = Date.today().addDays(60)
        );
        insert taxCase;
        Test.stopTest();

        List<Task> tasks = [SELECT Id, Subject, ActivityDate FROM Task WHERE WhatId = :taxCase.Id ORDER BY ActivityDate];

        // Custom Metadataが存在する場合はそのタスク数、存在しない場合は4つのデフォルトタスク
        System.assert(tasks.size() > 0, 'Should create tasks');

        // 法人税のタスクかデフォルトタスクが作成されることを確認
        Boolean hasValidTask = false;
        for (Task t : tasks) {
            if (t.Subject.contains('決算書類回収') || t.Subject.contains('書類回収依頼')) {
                hasValidTask = true;
                break;
            }
        }
        System.assert(hasValidTask, 'Should create valid tasks for corporate tax or default');
    }
    
    @isTest
    static void testTaskRegeneration() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Tax_Case__c taxCase = new Tax_Case__c(
            Account__c = acc.Id,
            Tax_Type__c = '法人税',
            Filing_Deadline__c = Date.today().addDays(60)
        );
        insert taxCase;

        Integer initialTaskCount = [SELECT COUNT() FROM Task WHERE WhatId = :taxCase.Id];

        Test.startTest();
        taxCase.Filing_Deadline__c = Date.today().addDays(90);
        update taxCase;
        Test.stopTest();

        Integer finalTaskCount = [SELECT COUNT() FROM Task WHERE WhatId = :taxCase.Id];
        System.assertEquals(initialTaskCount, finalTaskCount, 'Should maintain same number of tasks after deadline update');
    }

    @isTest
    static void testCustomMetadataFallback() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        // 消費税でテスト（Custom Metadataが未設定の場合はデフォルトタスクが作成される）
        Tax_Case__c taxCase = new Tax_Case__c(
            Account__c = acc.Id,
            Tax_Type__c = '消費税',
            Filing_Deadline__c = Date.today().addDays(60)
        );
        insert taxCase;
        Test.stopTest();

        List<Task> tasks = [SELECT Id, Subject FROM Task WHERE WhatId = :taxCase.Id ORDER BY ActivityDate];
        System.assert(tasks.size() > 0, 'Should create tasks');

        // Custom Metadataが存在するかデフォルトタスクが作成されるかを確認
        Boolean hasValidTask = false;
        for (Task t : tasks) {
            if (t.Subject.contains('取引データ回収') || t.Subject.contains('書類回収依頼')) {
                hasValidTask = true;
                break;
            }
        }
        System.assert(hasValidTask, 'Should create valid tasks');
    }
}