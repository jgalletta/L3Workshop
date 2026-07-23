import { CalendarClock } from 'lucide-react';
import { TableauEmbed } from '@/components/insights/TableauEmbed';

/**
 * "Book Appointment" — a DMV field-office appointment page. The embedded Tableau
 * Cloud dashboard (full width) is the centerpiece; it shows appointment
 * availability / office data. (Reshaped from the former Service Insights page.)
 */
export default function BookAppointment() {
  return (
    <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
      <div className="mb-8">
        <span className="inline-flex items-center gap-2 rounded-full bg-dmv-blue-10 px-3 py-1 text-xs font-medium text-dmv-blue">
          <CalendarClock className="h-3.5 w-3.5" />
          Appointments
        </span>
        <h1 className="mt-3 text-3xl font-bold text-dmv-navy">
          Book an Appointment
        </h1>
        <p className="mt-2 max-w-2xl text-base text-dmv-slate">
          Schedule a visit to a DMV field office. Review availability below and
          choose a time that works for you.
        </p>
      </div>

      {/* Full-width Tableau dashboard */}
      <TableauEmbed />
    </div>
  );
}
