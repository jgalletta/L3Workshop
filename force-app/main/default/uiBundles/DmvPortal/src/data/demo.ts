/**
 * Curated demo data for the DMV portal. Dropdown options, the signed-in
 * resident profile, service tiles, and document checklists. Lookups are mocked
 * here; the renewal record + document uploads persist for real to Salesforce
 * (see api/renewalApi.ts). Fictional data only.
 */
import {
  IdCard,
  FileText,
  CalendarClock,
  BadgeCheck,
  Car,
  ShieldCheck,
  type LucideIcon,
} from 'lucide-react';

/**
 * Keep the demo evergreen: the license always expires ~90 days out from
 * whenever the portal loads, so the "expiring soon" callout never rots into
 * the past (a hardcoded date silently slips out of date once the calendar
 * passes it). A real Date (not a date-only string) also avoids the UTC-parse
 * off-by-one that shifts the displayed day back one in Pacific time.
 */
const licenseExpiry = new Date();
licenseExpiry.setDate(licenseExpiry.getDate() + 90);

/** The signed-in resident (admin previews as this person). */
export const resident = {
  fullName: 'Jay Walker',
  licenseNumber: 'D1234567',
  dateOfBirth: '1990-05-14',
  email: 'jay.walker@example.gov',
  phone: '(916) 555-0184',
  address: {
    street: '1500 Capitol Mall, Apt 12',
    city: 'Sacramento',
    region: 'CA',
    postal: '95814',
  },
  currentLicense: {
    type: 'Class C — Noncommercial',
    issued: '2021-06-02',
    expires: licenseExpiry,
    realId: false,
  },
};

export interface ServiceTile {
  title: string;
  description: string;
  icon: LucideIcon;
  to?: string;
  badge?: string;
}

/** Home-page service tiles. */
export const serviceTiles: ServiceTile[] = [
  {
    title: 'Renew DL/ID',
    description:
      'Renew your driver license or identification card online in minutes.',
    icon: IdCard,
    to: '/renew',
    badge: 'Popular',
  },
  {
    title: 'Ask DMV',
    description:
      'Get instant answers about renewals, REAL ID, fees, and appointments.',
    icon: FileText,
    to: '/assistant',
  },
  {
    title: 'Book Appointment',
    description:
      'Schedule a visit to a DMV field office at a time that works for you.',
    icon: CalendarClock,
    to: '/appointment',
  },
  {
    title: 'REAL ID',
    description:
      'Learn what documents you need and upgrade to a federally compliant REAL ID.',
    icon: ShieldCheck,
    badge: 'Info',
  },
  {
    title: 'Vehicle Registration',
    description:
      'Renew registration, replace stickers, and submit proof of insurance.',
    icon: Car,
  },
  {
    title: 'Check Status',
    description:
      'Track the status of a renewal, application, or document review.',
    icon: BadgeCheck,
  },
];

/** Renewal reason picklist. */
export const renewalReasons = [
  { value: 'expiring', label: 'My license is expiring soon' },
  { value: 'expired', label: 'My license has already expired' },
  { value: 'realid', label: 'I want to upgrade to a REAL ID' },
  { value: 'name_change', label: 'My name has changed' },
];

/** License classes. */
export const licenseClasses = [
  { value: 'C', label: 'Class C — Noncommercial (cars, small trucks)' },
  { value: 'M', label: 'Class M — Motorcycle' },
  { value: 'A', label: 'Class A — Commercial (combination vehicles)' },
  { value: 'B', label: 'Class B — Commercial (single vehicles)' },
];

export interface RequiredDoc {
  key: string;
  label: string;
  hint: string;
  required: boolean;
}

/** Document checklist for the upload step (REAL ID-style proofs). */
export const requiredDocs: RequiredDoc[] = [
  {
    key: 'identity',
    label: 'Proof of Identity',
    hint: 'U.S. passport, birth certificate, or permanent resident card.',
    required: true,
  },
  {
    key: 'ssn',
    label: 'Proof of Social Security',
    hint: 'Social Security card, W-2, or paystub showing full SSN.',
    required: true,
  },
  {
    key: 'residency1',
    label: 'Proof of Residency (1 of 2)',
    hint: 'Utility bill, rental agreement, or bank statement.',
    required: true,
  },
  {
    key: 'residency2',
    label: 'Proof of Residency (2 of 2)',
    hint: 'A second, different residency document.',
    required: false,
  },
];

/** Side-rail checklist for the "Apply for a New License" page. */
export const newLicenseChecklist = [
  {
    label: 'Proof of identity',
    hint: 'U.S. passport, birth certificate, or permanent resident card.',
    done: false,
  },
  {
    label: 'Proof of residency',
    hint: 'Utility bill, rental agreement, or bank statement.',
    done: false,
  },
  {
    label: 'Application fee',
    hint: 'Paid online at the end of your application.',
    done: false,
  },
];

/** Live-ish application summary shown alongside the agent. */
export const applicationSummary = [
  { label: 'Status', value: 'Draft' },
  { label: 'License class', value: '—' },
  { label: 'REAL ID', value: '—' },
  { label: 'Started', value: 'Just now' },
];

/**
 * Hard-coded confirmed appointment for the demo. The time is computed at render
 * (1 hour from "now") so it always reads as a plausible upcoming slot rather
 * than rotting into the past — see the Appointment page for the live formatting.
 */
export const confirmedAppointment = {
  location: '5167 Figueroa',
  city: 'Los Angeles, CA 90042',
  type: "Driver's License Application",
  estimatedWait: '40 minutes',
  confirmationNumber: 'APT-4837-DMV',
};
