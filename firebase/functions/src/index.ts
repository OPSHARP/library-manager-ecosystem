import * as admin from "firebase-admin";

admin.initializeApp();

export {onUserCreate} from "./user_management";
export {sendFeeReminders} from "./fee_reminders";
export {sendAttendanceAlerts} from "./attendance_alerts";
export {generateMonthlyReport, autoBackup} from "./report_generator";
export {validateSubscriptionPurchase, cleanupExpiredSubscriptions} from "./subscription_validation";
export {sendStudentNotification} from "./student_notifications";
export {joinLibrary, verifyStudentId, sendJoinRequest, acceptJoinRequest, createStudentProfile, updateStudentProfile, recordStudentLeave, kickStudent, requestLibraryLeave, approveLeaveRequest} from "./student_library";
