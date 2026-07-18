import { HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";

const id = z.string().trim().min(1).max(128);
const details = z.string().trim().max(1000).default("");

export const createBookingSchema = z.object({
  serviceId: id,
  dateKey: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  timeWindow: z.enum(["morning", "afternoon", "evening"]),
  serviceAreaKey: z.string().trim().min(1).max(80),
  address: z.string().trim().min(5).max(500),
  landmark: z.string().trim().max(200).default(""),
  notes: z.string().trim().max(500).default(""),
});

export const bookingIdSchema = z.object({ bookingId: id });
export const respondSchema = z.object({
  bookingId: id,
  decision: z.enum(["accept", "reject"]),
  reason: z.string().trim().max(500).optional(),
});
export const cancelSchema = z.object({
  bookingId: id,
  reason: z.string().trim().min(1).max(80),
  details,
});
export const disputeSchema = z.object({
  bookingId: id,
  reason: z.string().trim().min(1).max(80),
  details: z.string().trim().min(3).max(1000),
});
export const messageSchema = z.object({
  bookingId: id,
  text: z.string().trim().min(1).max(1000),
});
export const reviewSchema = z.object({
  bookingId: id,
  rating: z.number().int().min(1).max(5),
  comment: z.string().trim().max(500).default(""),
});
export const reportSchema = z.object({
  bookingId: id,
  targetType: z.enum(["user", "message"]),
  targetId: id,
  reason: z.enum([
    "abusive_content",
    "harassment",
    "spam",
    "fraud",
    "unsafe_behavior",
    "objectionable_content",
    "other",
  ]),
  details,
});
export const blockSchema = z.object({ targetUid: id, blocked: z.boolean() });

export function parse<T>(schema: z.ZodType<T>, data: unknown): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw new HttpsError("invalid-argument", result.error.issues[0]?.message ?? "Invalid request.");
  }
  return result.data;
}
