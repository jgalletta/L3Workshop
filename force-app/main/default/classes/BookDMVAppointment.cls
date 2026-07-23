/**
 * Invocable action for the DMV Appointment Assisting Agent.
 *
 * Books a DMV appointment by inserting a DMV_Appointment__c record. The office
 * snapshot fields (wait, congestion, geo, travel) are passed in from the ranked
 * option the user chose, so the record captures the conditions at booking time.
 *
 * Time slots are arbitrary 1-hour slots (9 AM - 4 PM) on the next available
 * business day (Mon-Fri).
 */
public without sharing class BookDMVAppointment {

    private static final Map<String, Integer> SLOT_HOUR = new Map<String, Integer>{
        '9:00 AM' => 9, '10:00 AM' => 10, '11:00 AM' => 11, '12:00 PM' => 12,
        '1:00 PM' => 13, '2:00 PM' => 14, '3:00 PM' => 15, '4:00 PM' => 16
    };

    public class Request {
        @InvocableVariable(label='Application Id' description='Application the appointment is for.' required=true)
        public String applicationId;
        @InvocableVariable(label='Contact Id' description='Contact the appointment is for, if known.')
        public String contactId;
        @InvocableVariable(label='Office Id' description='Chosen DMV office id.' required=true)
        public String officeId;
        @InvocableVariable(label='Office Name' description='Chosen DMV office name.')
        public String officeName;
        @InvocableVariable(label='Office City' description='Office city.')
        public String officeCity;
        @InvocableVariable(label='Office Region' description='Office region.')
        public String officeRegion;
        @InvocableVariable(label='Office Latitude' description='Office latitude.')
        public Decimal officeLatitude;
        @InvocableVariable(label='Office Longitude' description='Office longitude.')
        public Decimal officeLongitude;
        @InvocableVariable(label='Service Type' description='DMV service type being booked.' required=true)
        public String serviceType;
        @InvocableVariable(label='Time Slot' description='One of: 9:00 AM, 10:00 AM, 11:00 AM, 12:00 PM, 1:00 PM, 2:00 PM, 3:00 PM, 4:00 PM.' required=true)
        public String timeSlot;
        @InvocableVariable(label='Expected Wait Minutes' description='Expected wait captured at booking.')
        public Decimal expectedWaitMinutes;
        @InvocableVariable(label='Congestion Status' description='Congestion status at booking.')
        public String congestionStatus;
        @InvocableVariable(label='Estimated Travel Minutes' description='Estimated travel time at booking.')
        public Decimal estimatedTravelMinutes;
    }

    public class Result {
        @InvocableVariable(label='Success' description='Whether the appointment was booked.')
        public Boolean success;
        @InvocableVariable(label='Appointment Number' description='The auto-number name of the created appointment.')
        public String appointmentNumber;
        @InvocableVariable(label='Appointment DateTime' description='The scheduled date and time.')
        public String appointmentDateTime;
        @InvocableVariable(label='Message' description='Human-readable confirmation or error.')
        public String message;
    }

    @InvocableMethod(
        label='Book DMV Appointment'
        description='Creates a DMV appointment record at the chosen office and time slot on the next business day.'
    )
    public static List<Result> book(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<DMV_Appointment__c> toInsert = new List<DMV_Appointment__c>();
        List<Result> perReq = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();
            res.success = false;
            perReq.add(res);

            String slotLabel = normalizeSlot(req.timeSlot);
            if (slotLabel == null) {
                res.message = 'Invalid time slot "' + req.timeSlot + '". Choose an hourly slot from 9:00 AM to 4:00 PM.';
                toInsert.add(null);
                continue;
            }

            DateTime slot = nextBusinessDaySlot(SLOT_HOUR.get(slotLabel));
            DMV_Appointment__c appt = new DMV_Appointment__c(
                Application__c = req.applicationId,
                Contact__c = req.contactId,
                Appointment_DateTime__c = slot,
                Time_Slot__c = slotLabel,
                Service_Type__c = req.serviceType,
                Office_Id__c = req.officeId,
                Office_Name__c = req.officeName,
                Office_City__c = req.officeCity,
                Office_Region__c = req.officeRegion,
                Office_Latitude__c = req.officeLatitude,
                Office_Longitude__c = req.officeLongitude,
                Expected_Wait_Minutes__c = req.expectedWaitMinutes,
                Congestion_Status__c = req.congestionStatus,
                Estimated_Travel_Minutes__c = req.estimatedTravelMinutes,
                Status__c = 'Scheduled'
            );
            toInsert.add(appt);
        }

        // Bulk insert the valid ones.
        List<DMV_Appointment__c> valid = new List<DMV_Appointment__c>();
        for (DMV_Appointment__c a : toInsert) {
            if (a != null) valid.add(a);
        }
        if (!valid.isEmpty()) {
            insert valid;
        }

        // Map results back (query names for the inserted records).
        Map<Id, DMV_Appointment__c> byId = new Map<Id, DMV_Appointment__c>();
        Set<Id> appIds = new Set<Id>();
        if (!valid.isEmpty()) {
            for (DMV_Appointment__c a : [SELECT Id, Name, Appointment_DateTime__c, Application__c FROM DMV_Appointment__c WHERE Id IN :valid]) {
                byId.put(a.Id, a);
                if (a.Application__c != null) appIds.add(a.Application__c);
            }
        }
        // Advance the linked Applications to Scheduled.
        if (!appIds.isEmpty()) {
            List<Application__c> apps = new List<Application__c>();
            for (Id appId : appIds) apps.add(new Application__c(Id = appId, Status__c = 'Scheduled'));
            update apps;
        }
        for (Integer i = 0; i < requests.size(); i++) {
            Result res = perReq.get(i);
            DMV_Appointment__c a = toInsert.get(i);
            if (a != null && a.Id != null) {
                DMV_Appointment__c saved = byId.get(a.Id);
                res.success = true;
                res.appointmentNumber = (saved != null) ? saved.Name : null;
                res.appointmentDateTime = String.valueOf(a.Appointment_DateTime__c);
                res.message = 'Appointment booked at ' + a.Office_Name__c + ' for ' + a.Service_Type__c + '.';
            }
            results.add(res);
        }
        return results;
    }

    /**
     * Normalizes a caller-supplied time slot into one of the canonical labels
     * (e.g. "10:00 AM"). Accepts the exact label, or falls back to extracting
     * the hour from an ISO datetime / "HH:00" style string the LLM may pass.
     * Returns null if it can't be mapped to a valid 9 AM - 4 PM hourly slot.
     */
    private static String normalizeSlot(String raw) {
        if (String.isBlank(raw)) return null;
        String s = raw.trim();
        if (SLOT_HOUR.containsKey(s)) return s;

        // Try to pull an hour out of an ISO timestamp like 2026-07-23T10:00:00
        Integer hour = null;
        Pattern p = Pattern.compile('T(\\d{1,2}):');
        Matcher m = p.matcher(s);
        if (m.find()) {
            hour = Integer.valueOf(m.group(1));
        } else {
            // Try leading "HH" or "H:MM"
            Pattern p2 = Pattern.compile('^(\\d{1,2})');
            Matcher m2 = p2.matcher(s);
            if (m2.find()) {
                hour = Integer.valueOf(m2.group(1));
                // Respect a trailing PM for 1-4 -> 13-16
                if (s.toUpperCase().contains('PM') && hour >= 1 && hour <= 4) {
                    hour += 12;
                }
            }
        }
        if (hour == null) return null;
        return HOUR_LABEL.get(hour);
    }

    private static final Map<Integer, String> HOUR_LABEL = new Map<Integer, String>{
        9 => '9:00 AM', 10 => '10:00 AM', 11 => '11:00 AM', 12 => '12:00 PM',
        13 => '1:00 PM', 14 => '2:00 PM', 15 => '3:00 PM', 16 => '4:00 PM'
    };

    /** Next Mon-Fri at the given hour; if that time today has passed or today is a weekend, roll forward. */
    private static DateTime nextBusinessDaySlot(Integer hour) {
        Date d = Date.today();
        DateTime candidate = DateTime.newInstance(d, Time.newInstance(hour, 0, 0, 0));
        // If today's slot already passed, start from tomorrow.
        if (candidate <= DateTime.now()) {
            d = d.addDays(1);
        }
        // Roll forward past weekends. DateTime.format('u') => 1=Mon .. 7=Sun.
        DateTime probe = DateTime.newInstance(d, Time.newInstance(hour, 0, 0, 0));
        String dow = probe.format('u');
        while (dow == '6' || dow == '7') {
            d = d.addDays(1);
            probe = DateTime.newInstance(d, Time.newInstance(hour, 0, 0, 0));
            dow = probe.format('u');
        }
        return DateTime.newInstance(d, Time.newInstance(hour, 0, 0, 0));
    }
}
