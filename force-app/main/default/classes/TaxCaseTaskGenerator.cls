public with sharing class TaxCaseTaskGenerator {   

    public static void generateTasks(List<Tax_Case__c> taxCases, Map<Id, Tax_Case__c> oldMap) {
        
        // 対象案件を抽出（新規 or 申告種別変更 or 期限変更）
        List<Tax_Case__c> targetCases = new List<Tax_Case__c>();
        Set<Id> caseIds = new Set<Id>();
        
        for (Tax_Case__c tc : taxCases) {
            if (shouldGenerateTasks(tc, oldMap)) {
                targetCases.add(tc);
                caseIds.add(tc.Id);
            }
        }
        
        if (targetCases.isEmpty()) return;
        
        // 既存タスク削除（再生成のため）
        List<Task> existingTasks = [
            SELECT Id FROM Task 
            WHERE WhatId IN :caseIds
        ];
        if (!existingTasks.isEmpty()) {
            delete existingTasks;
        }
        
        // 新規タスク作成
        List<Task> newTasks = new List<Task>();
        
        for (Tax_Case__c tc : targetCases) {
            newTasks.addAll(createTasksForCase(tc));
        }
        
        if (!newTasks.isEmpty()) {
            insert newTasks;
        }
    }
    
    private static Boolean shouldGenerateTasks(Tax_Case__c newCase, Map<Id, Tax_Case__c> oldMap) {
        if (oldMap == null) return true; // 新規作成
        
        Tax_Case__c oldCase = oldMap.get(newCase.Id);
        
        // 申告期限が変更された場合
        if (newCase.Filing_Deadline__c != oldCase.Filing_Deadline__c) {
            return true;
        }
        
        return false; // 変更なし：タスク再生成不要
    }
    
    private static List<Task> createTasksForCase(Tax_Case__c taxCase) {
        List<Task> tasks = new List<Task>();
        Date deadline = taxCase.Filing_Deadline__c;
        String taxType = taxCase.Tax_Type__c;

        if (deadline == null || taxType == null) return tasks;

        // Custom Metadataからタスクテンプレートを取得
        List<Tax_Task_Template__mdt> taskTemplates = [
            SELECT Task_Name__c, Days_Before_Deadline__c, Sort_Order__c
            FROM Tax_Task_Template__mdt
            WHERE Tax_Type__c = :taxType
            ORDER BY Sort_Order__c ASC
        ];

        // テンプレートが存在しない場合はデフォルトタスクを作成
        if (taskTemplates.isEmpty()) {
            tasks.addAll(createDefaultTasks(deadline, taxCase.Id, taxCase.Assignee__c));
        } else {
            // Custom Metadataベースでタスク作成
            for (Tax_Task_Template__mdt template : taskTemplates) {
                Integer daysBefore = -Integer.valueOf(template.Days_Before_Deadline__c);
                Date dueDate = addBusinessDays(deadline, daysBefore);
                tasks.add(createTask(template.Task_Name__c, dueDate, taxCase.Id, taxCase.Assignee__c));
            }
        }

        return tasks;
    }

    // デフォルトタスク（Custom Metadataが未設定の場合）
    private static List<Task> createDefaultTasks(Date deadline, Id whatId, Id ownerId) {
        List<Task> tasks = new List<Task>();
        tasks.add(createTask('書類回収依頼', addBusinessDays(deadline, -30), whatId, ownerId));
        tasks.add(createTask('下書き作成', addBusinessDays(deadline, -14), whatId, ownerId));
        tasks.add(createTask('レビュー', addBusinessDays(deadline, -7), whatId, ownerId));
        tasks.add(createTask('提出準備', addBusinessDays(deadline, -1), whatId, ownerId));
        return tasks;
    }
    
    private static Task createTask(String subject, Date dueDate, Id whatId, Id ownerId) {
        Task t = new Task();
        t.Subject = subject;
        t.ActivityDate = dueDate;
        t.WhatId = whatId;
        t.OwnerId = ownerId != null ? ownerId : UserInfo.getUserId();
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        return t;
    }
    
    private static Date addBusinessDays(Date startDate, Integer days) {
        Date resultDate = startDate;
        Integer daysToAdd = Math.abs(days);
        Integer direction = days < 0 ? -1 : 1;
        
        for (Integer i = 0; i < daysToAdd; i++) {
            resultDate = resultDate.addDays(direction);
            
            // 土日をスキップ
            while (isWeekend(resultDate)) {
                resultDate = resultDate.addDays(direction);
            }
        }
        
        return resultDate;
    }
    
    private static Boolean isWeekend(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        String dayOfWeek = dt.format('E');
        return dayOfWeek == 'Sat' || dayOfWeek == 'Sun';
    }
}