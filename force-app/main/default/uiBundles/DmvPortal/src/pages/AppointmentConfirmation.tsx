import {
  CheckCircle2,
  CalendarClock,
  MapPin,
  FileText,
  Clock,
  Bell,
  Printer,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { resident, confirmedAppointment } from '@/data/demo';

/**
 * "Appointment Confirmation" — a hard-coded confirmed appointment for the demo.
 *
 * The appointment time is computed at render as (now + 1 hour) so the slot
 * always reads as a plausible upcoming time and never rots into the past. All
 * other details (location, type, wait) come from demo data.
 */
export default function AppointmentConfirmation() {
  // 1 hour from now — evergreen so the demo never shows a past time.
  const start = new Date();
  start.setHours(start.getHours() + 1);
  const dateLabel = start.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });
  const timeLabel = start.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  });

  const details = [
    {
      icon: CalendarClock,
      label: 'Date & time',
      value: `${dateLabel} at ${timeLabel}`,
    },
    {
      icon: MapPin,
      label: 'Location',
      value: confirmedAppointment.location,
      sub: confirmedAppointment.city,
    },
    {
      icon: FileText,
      label: 'Appointment type',
      value: confirmedAppointment.type,
    },
    {
      icon: Clock,
      label: 'Estimated wait time',
      value: confirmedAppointment.estimatedWait,
    },
  ];

  return (
    <div className="mx-auto max-w-3xl px-4 py-14 sm:px-6 lg:px-8">
      {/* Success hero */}
      <div className="text-center">
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-dmv-success-bg text-dmv-success">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 text-3xl font-bold text-dmv-navy sm:text-4xl">
          Hi {resident.fullName}, your appointment is confirmed
        </h1>
        <p className="mx-auto mt-3 max-w-xl text-base leading-relaxed text-dmv-slate">
          We&apos;ve reserved your spot. A confirmation has been sent to{' '}
          {resident.email}. Please arrive 10 minutes early and bring the
          documents from your application checklist.
        </p>
      </div>

      {/* Confirmation number */}
      <div className="mx-auto mt-8 flex max-w-xs items-center justify-between gap-4 rounded-xl border border-dmv-line bg-dmv-sky px-5 py-3">
        <span className="text-xs font-medium uppercase tracking-wide text-dmv-slate">
          Confirmation
        </span>
        <span className="text-lg font-bold tracking-tight text-dmv-navy">
          {confirmedAppointment.confirmationNumber}
        </span>
      </div>

      {/* Details card */}
      <Card className="mt-8 shadow-dmv-sm">
        <CardContent className="p-0">
          <div className="border-b border-dmv-line bg-dmv-navy px-6 py-4">
            <h2 className="flex items-center gap-2 text-sm font-semibold text-white">
              <CalendarClock className="h-4 w-4 text-dmv-gold" />
              Appointment details
            </h2>
          </div>
          <dl className="divide-y divide-dmv-line">
            {details.map(d => {
              const Icon = d.icon;
              return (
                <div key={d.label} className="flex items-start gap-4 px-6 py-4">
                  <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-dmv-blue-10 text-dmv-blue">
                    <Icon className="h-4.5 w-4.5" />
                  </span>
                  <div>
                    <dt className="text-xs font-medium uppercase tracking-wide text-dmv-slate">
                      {d.label}
                    </dt>
                    <dd className="mt-0.5 text-base font-semibold text-dmv-ink">
                      {d.value}
                    </dd>
                    {d.sub && (
                      <dd className="text-sm text-dmv-slate">{d.sub}</dd>
                    )}
                  </div>
                </div>
              );
            })}
          </dl>
        </CardContent>
      </Card>

      {/* Reminder note */}
      <div className="mt-6 flex items-start gap-3 rounded-xl border border-dmv-gold-20 bg-dmv-gold-10 p-4">
        <Bell className="mt-0.5 h-5 w-5 shrink-0 text-dmv-warning" />
        <p className="text-sm text-dmv-slate">
          We&apos;ll send you a reminder the day before. Need to make a change?
          You can reschedule or cancel any time before your appointment.
        </p>
      </div>

      {/* Actions */}
      <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
        <Button size="lg" className="gap-2">
          <CalendarClock className="h-4 w-4" />
          Add to calendar
        </Button>
        <Button variant="outline" size="lg" className="gap-2">
          <Printer className="h-4 w-4" />
          Print confirmation
        </Button>
      </div>

      <p className="mx-auto mt-10 max-w-xl text-center text-xs text-dmv-mist">
        This is a demonstration confirmation. No real appointment has been
        scheduled.
      </p>
    </div>
  );
}
