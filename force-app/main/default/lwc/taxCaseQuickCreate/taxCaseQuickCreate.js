import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const FIELDS = ['Account.Fiscal_Year_End__c', 'Account.Tax_Accountant__c'];

export default class TaxCaseQuickCreate extends LightningElement {
    @api recordId;
    accountData;
    selectedTaxType = '';
    isLoading = false;

    // 申告種別の選択肢
    taxTypeOptions = [
        { label: '法人税', value: '法人税' },
        { label: '消費税', value: '消費税' },
        { label: '所得税', value: '所得税' },
        { label: '相続税', value: '相続税' }
    ];

    // ボタンの無効化制御
    get isCreateDisabled() {
        return !this.selectedTaxType || this.isLoading;
    }

    // ボタンラベルの動的制御
    get buttonLabel() {
        return this.isLoading ? '作成中...' : '申告案件を作成';
    }

    // バリデーションメッセージ表示用
    showValidationMessage() {
        if (!this.selectedTaxType) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'エラー',
                    message: '申告種別を選択してください。申告種別により期限が自動計算されます。',
                    variant: 'error'
                })
            );
            return false;
        }
        return true;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount(result) {
        this.accountData = result;
    }

    // 申告種別選択時の処理
    handleTaxTypeChange(event) {
        this.selectedTaxType = event.detail.value;
    }

    handleCreateTaxCase() {
        if (!this.showValidationMessage()) {
            return;
        }

        this.isLoading = true;

        const fields = {};
        fields.Account__c = this.recordId;
        fields.Tax_Type__c = this.selectedTaxType;

        // 税目別に申告期限を計算
        const fiscalMonth = this.accountData.data.fields.Fiscal_Year_End__c.value;
        console.log('Account Data:', this.accountData);
        console.log('fiscalMonth from field:', fiscalMonth);

        if (!fiscalMonth) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'エラー',
                    message: 'アカウントの決算月が設定されていません。アカウント情報を確認してください。',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        fields.Filing_Deadline__c = this.calculateFilingDeadline(this.selectedTaxType, fiscalMonth);

        const recordInput = { apiName: 'Tax_Case__c', fields };

        createRecord(recordInput)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: '成功',
                        message: `${this.selectedTaxType}申告案件を作成しました`,
                        variant: 'success'
                    })
                );
                // 選択をリセット
                this.selectedTaxType = '';
                // リフレッシュ
                return refreshApex(this.accountData);
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'エラー',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    calculateFilingDeadline(taxType, fiscalMonthStr) {
        const monthMap = {
            '1月': 0, '2月': 1, '3月': 2, '4月': 3, '5月': 4, '6月': 5,
            '7月': 6, '8月': 7, '9月': 8, '10月': 9, '11月': 10, '12月': 11
        };

        const fiscalMonth = monthMap[fiscalMonthStr];

        // デバッグ用
        console.log('fiscalMonthStr:', fiscalMonthStr);
        console.log('fiscalMonth:', fiscalMonth);

        if (fiscalMonth === undefined) {
            console.error('Invalid fiscalMonthStr:', fiscalMonthStr);
            return null;
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0); // 時間を0時にリセットして日付比較を正確にする
        let year = today.getFullYear();
        let deadline;

        // 税目別の申告期限計算
        switch (taxType) {
            case '法人税':
            case '消費税': {
                // 決算月の2ヶ月後の月末
                let deadlineMonth = fiscalMonth + 2;
                let deadlineYear = year;
                if (deadlineMonth > 11) {
                    deadlineMonth = deadlineMonth - 12;
                    deadlineYear++;
                }

                // 月末日を明示的に計算
                const lastDayOfMonth = new Date(deadlineYear, deadlineMonth + 1, 0).getDate();
                deadline = new Date(deadlineYear, deadlineMonth, lastDayOfMonth);
                console.log('deadlineYear:', deadlineYear, 'deadlineMonth:', deadlineMonth, 'lastDayOfMonth:', lastDayOfMonth);
                console.log('Initial deadline:', deadline);

                // 本日以降の日付になるまで年を進める
                let loopCount = 0;
                while (deadline <= today && loopCount < 10) {
                    deadlineYear++;
                    const nextLastDay = new Date(deadlineYear, deadlineMonth + 1, 0).getDate();
                    deadline = new Date(deadlineYear, deadlineMonth, nextLastDay);
                    loopCount++;
                    console.log('Loop iteration:', loopCount, 'deadline:', deadline);
                }
                break;
            }
            case '所得税':
                // 3月15日（本年が過ぎていたら翌年）
                deadline = new Date(year, 2, 15); // 3月15日
                if (deadline <= today) {
                    year++;
                    deadline = new Date(year, 2, 15);
                }
                break;
            case '相続税':
                // 6月30日（本年が過ぎていたら翌年）
                deadline = new Date(year, 5, 30); // 6月30日
                if (deadline <= today) {
                    year++;
                    deadline = new Date(year, 5, 30);
                }
                break;
            default: {
                // デフォルトは法人税と同じ
                let defaultDeadlineMonth = fiscalMonth + 2;
                let defaultDeadlineYear = year;
                if (defaultDeadlineMonth > 11) {
                    defaultDeadlineMonth = defaultDeadlineMonth - 12;
                    defaultDeadlineYear++;
                }

                deadline = new Date(defaultDeadlineYear, defaultDeadlineMonth + 1, 0);
                while (deadline <= today) {
                    defaultDeadlineYear++;
                    deadline = new Date(defaultDeadlineYear, defaultDeadlineMonth + 1, 0);
                }
            }
        }

        // Use timezone-safe date formatting to avoid UTC conversion issues
        const finalYear = deadline.getFullYear();
        const finalMonth = String(deadline.getMonth() + 1).padStart(2, '0');
        const finalDay = String(deadline.getDate()).padStart(2, '0');
        return `${finalYear}-${finalMonth}-${finalDay}`;
    }
}