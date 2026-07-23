import type { RouteObject } from 'react-router';
import AppLayout from '@/appLayout';
import Home from './pages/Home';
import NotFound from './pages/NotFound';
import ApplyLicense from './pages/ApplyLicense';
import Assistant from './pages/Assistant';
import BookAppointment from './pages/BookAppointment';
import AppointmentConfirmation from './pages/AppointmentConfirmation';

export const routes: RouteObject[] = [
  {
    path: '/',
    element: <AppLayout />,
    children: [
      {
        index: true,
        element: <Home />,
        handle: { showInNavigation: true, label: 'Home' },
      },
      {
        path: 'renew',
        element: <ApplyLicense />,
        handle: { showInNavigation: true, label: 'Apply for License' },
      },
      {
        path: 'assistant',
        element: <Assistant />,
        handle: { showInNavigation: true, label: 'Ask DMV' },
      },
      {
        path: 'appointment',
        element: <BookAppointment />,
        handle: { showInNavigation: true, label: 'Book Appointment' },
      },
      {
        path: 'appointments',
        element: <AppointmentConfirmation />,
        handle: { showInNavigation: true, label: 'Appointments' },
      },
      {
        path: '*',
        element: <NotFound />,
      },
    ],
  },
];
