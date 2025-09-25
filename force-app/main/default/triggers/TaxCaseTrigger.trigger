trigger TaxCaseTrigger on Tax_Case__c (after insert, after update) {
    TaxCaseTaskGenerator.generateTasks(Trigger.new, Trigger.oldMap);
}