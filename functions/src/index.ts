import * as functionsV1 from "firebase-functions/v1";
import { cleanupUserData, requestAccountDeletion } from "./accounts";
import {
  cancelBooking,
  cleanupReleasedProviderSlot,
  confirmCompletion,
  createBooking,
  disputeCompletion,
  requestCompletion,
  respondToBooking,
  startBooking,
} from "./bookings";
import { checkCommunication, sendMessage } from "./chat";
import { setUserBlocked, submitReport } from "./moderation";
import {
  recalculateProviderRating,
  refreshProviderCompletedCount,
  submitReview,
} from "./reviews";

export {
  cancelBooking,
  cleanupReleasedProviderSlot,
  checkCommunication,
  confirmCompletion,
  createBooking,
  disputeCompletion,
  recalculateProviderRating,
  refreshProviderCompletedCount,
  requestAccountDeletion,
  requestCompletion,
  respondToBooking,
  sendMessage,
  setUserBlocked,
  startBooking,
  submitReport,
  submitReview,
};

// Firebase Authentication lifecycle deletion remains a first-generation-only
// trigger. All callable and Firestore triggers above are Gen 2 in asia-south1.
export const cleanupDeletedAuthUser = functionsV1
  .runWith({ memory: "256MB", maxInstances: 3 })
  .region("asia-east2")
  .auth.user()
  .onDelete(async (user) => cleanupUserData(user.uid));
