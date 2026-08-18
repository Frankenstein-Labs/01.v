import { DASHBOARD_TYPE_GROUP } from 'ee/security_dashboard/constants';
import vulnerabilityReportInit from 'ee/security_dashboard/vulnerability_report_init';

vulnerabilityReportInit(document.getElementById('js-group-vulnerabilities'), DASHBOARD_TYPE_GROUP);
