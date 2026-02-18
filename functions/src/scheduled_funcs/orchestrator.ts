// ──────────────────────────────────────────────────────────────────────────────
// File: src/scheduled_funcs/orchestrator.ts
// Purpose: Orchestrate scheduled publishing and notifications in proper sequence
// ──────────────────────────────────────────────────────────────────────────────
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { doCommentPublicationScheduleRefresh } from "./comment_publication_schedule";
import { doCommentPublish } from "./comment_publisher";
import { doCommitteeResponsePublish } from "./committee_response_publisher";
import { doEnquiryPublish } from "./enquiry_publisher";
import { doTeamResponsePublish } from "./team_response_publisher";
import { SCHED_REGION_ROME, ROME_TZ, TIMEOUT_SECONDS } from "../common/config";
import { doSendPublishDigest } from "../notifications/send_publish_digest";

/**
 * Orchestrate 0:00 slot publications and digest.
 * Runs functions sequentially to ensure all publishes complete before digest sent.
 *
 * Sequence:
 * 1. Publish enquiries
 * 2. Publish comments
 * 3. Publish RC responses
 * 4. Update comment publication schedule
 * 5. Send digest to users
 */
export const orchestrate0000 = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "0 0 * * *",
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    const startTime = Date.now();
    logger.info("[orchestrate0000] Starting 0:00 publication cycle");

    try {
      await doEnquiryPublish();
      logger.info("[orchestrate0000] ✅ enquiryPublish complete");

      await doCommentPublish();
      logger.info("[orchestrate0000] ✅ commentPublish complete");

      await doCommitteeResponsePublish();
      logger.info("[orchestrate0000] ✅ committeeResponsePublish complete");

      await doCommentPublicationScheduleRefresh();
      logger.info(
        "[orchestrate0000] ✅ commentPublicationScheduleRefresh complete",
      );

      await doSendPublishDigest();
      logger.info("[orchestrate0000] ✅ sendPublishDigest complete");

      const duration = (Date.now() - startTime) / 1000;
      logger.info(
        `[orchestrate0000] ✅ All operations complete in ${duration}s`,
      );
    } catch (error) {
      logger.error("[orchestrate0000] ❌ Publication cycle failed", {
        error: String(error),
        duration: (Date.now() - startTime) / 1000,
      });
      throw error;
    }
  },
);

/**
 * Orchestrate 12:00 slot publications and digest.
 *
 * Sequence:
 * 1. Publish enquiries
 * 2. Publish comments
 * 3. Send digest to users
 */
export const orchestrate1200 = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "0 12 * * *",
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    const startTime = Date.now();
    logger.info("[orchestrate1200] Starting 12:00 publication cycle");

    try {
      await doEnquiryPublish();
      logger.info("[orchestrate1200] ✅ enquiryPublish complete");

      await doCommentPublish();
      logger.info("[orchestrate1200] ✅ commentPublish complete");

      await doSendPublishDigest();
      logger.info("[orchestrate1200] ✅ sendPublishDigest complete");

      const duration = (Date.now() - startTime) / 1000;
      logger.info(
        `[orchestrate1200] ✅ All operations complete in ${duration}s`,
      );
    } catch (error) {
      logger.error("[orchestrate1200] ❌ Publication cycle failed", {
        error: String(error),
        duration: (Date.now() - startTime) / 1000,
      });
      throw error;
    }
  },
);

/**
 * Orchestrate 20:00 slot publications and digest.
 *
 * Sequence:
 * 1. Publish team (competitor) responses
 * 2. Send digest to users
 *
 * Note: This runs after the response submission deadline (20:00).
 * No submissions are locked; responses submitted before 20:00 are valid.
 */
export const orchestrate2000 = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "0 20 * * *",
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    const startTime = Date.now();
    logger.info("[orchestrate2000] Starting 20:00 publication cycle");

    try {
      await doTeamResponsePublish();
      logger.info("[orchestrate2000] ✅ teamResponsePublish complete");

      await doSendPublishDigest();
      logger.info("[orchestrate2000] ✅ sendPublishDigest complete");

      const duration = (Date.now() - startTime) / 1000;
      logger.info(
        `[orchestrate2000] ✅ All operations complete in ${duration}s`,
      );
    } catch (error) {
      logger.error("[orchestrate2000] ❌ Publication cycle failed", {
        error: String(error),
        duration: (Date.now() - startTime) / 1000,
      });
      throw error;
    }
  },
);
