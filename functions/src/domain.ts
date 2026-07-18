export const bookingStatuses = [
  "pending",
  "accepted",
  "rejected",
  "cancelled",
  "inProgress",
  "completionRequested",
  "completed",
  "disputed",
] as const;

export type BookingStatus = (typeof bookingStatuses)[number];
export type UserRole = "customer" | "provider";
export type AccountStatus = "active" | "suspended" | "deletionPending" | "deleted";
export type ProviderApprovalStatus = "pending" | "approved" | "rejected";
export type ServiceStatus = "active" | "archived";
export type TimeWindow = "morning" | "afternoon" | "evening";
export type PaymentStatus = "unpaid" | "paidCash" | "disputed";
export type ReportTarget = "user" | "message";
export type ReportStatus = "open" | "reviewing" | "resolved" | "dismissed";
export type NotificationType = "booking" | "message" | "review" | "moderation" | "account";

export const terminalStatuses = new Set<BookingStatus>([
  "rejected",
  "cancelled",
  "completed",
  "disputed",
]);

export const chatStatuses = new Set<BookingStatus>([
  "accepted",
  "inProgress",
  "completionRequested",
]);

export const cancellableStatuses = new Set<BookingStatus>(["pending", "accepted"]);
export const occupiedStatuses: BookingStatus[] = ["accepted", "inProgress", "completionRequested"];

export function canTransition(from: BookingStatus, to: BookingStatus): boolean {
  const allowed: Record<BookingStatus, BookingStatus[]> = {
    pending: ["accepted", "rejected", "cancelled"],
    accepted: ["inProgress", "cancelled"],
    rejected: [],
    cancelled: [],
    inProgress: ["completionRequested"],
    completionRequested: ["completed", "disputed"],
    completed: [],
    disputed: [],
  };
  return allowed[from].includes(to);
}

export function dhakaDateKey(date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Dhaka",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const part = (type: Intl.DateTimeFormatPartTypes) => parts.find((value) => value.type === type)?.value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export function isValidDhakaDateKey(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00+06:00`);
  return !Number.isNaN(parsed.getTime()) && dhakaDateKey(parsed) === value;
}

export function normalizeKey(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}
