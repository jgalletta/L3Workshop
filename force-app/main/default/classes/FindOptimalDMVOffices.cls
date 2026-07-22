/**
 * Invocable action for the DMV Appointment Assisting Agent.
 *
 * Given a Contact (whose mailing lat/long was populated upstream from ingested
 * documents) and a requested service type, this:
 *   1. queries the Current DMV Wait Times DMO for appointment-eligible offices
 *      offering that service (latest reading per office),
 *   2. calls the Google Distance Matrix API for real drive time from the
 *      contact to each office,
 *   3. returns offices ranked by a blended score of travel + wait time so the
 *      agent can recommend the option with the least total time.
 */
public without sharing class FindOptimalDMVOffices {

    // Weighting for the blended score. Travel and wait are both in minutes, so
    // the score is "estimated total minutes" — travel weighted slightly higher
    // since it's a fixed cost the user always pays.
    private static final Decimal TRAVEL_WEIGHT = 1.0;
    private static final Decimal WAIT_WEIGHT = 1.0;
    private static final Integer MAX_OFFICES = 5;

    public class Request {
        @InvocableVariable(
            label='Contact Id'
            description='Id of the Contact requesting the appointment. Mailing latitude/longitude are read from this record.'
            required=true
        )
        public String contactId;
        @InvocableVariable(
            label='Service Type'
            description='The DMV service type the user needs, for example Driver License Renewal or Behind-the-Wheel Test.'
            required=true
        )
        public String serviceType;
    }

    public class OfficeOption {
        @InvocableVariable(label='Office Id' description='DMV office identifier.')
        public String officeId;
        @InvocableVariable(label='Office Name' description='DMV office name.')
        public String officeName;
        @InvocableVariable(label='City' description='Office city.')
        public String city;
        @InvocableVariable(label='Region' description='Office region.')
        public String region;
        @InvocableVariable(label='Latitude' description='Office latitude.')
        public Decimal latitude;
        @InvocableVariable(label='Longitude' description='Office longitude.')
        public Decimal longitude;
        @InvocableVariable(label='Expected Wait Minutes' description='Latest observed wait time in minutes.')
        public Decimal expectedWaitMinutes;
        @InvocableVariable(label='Congestion Status' description='LOW, MODERATE, or HIGH.')
        public String congestionStatus;
        @InvocableVariable(label='Estimated Travel Minutes' description='Driving time from the contact to this office.')
        public Decimal estimatedTravelMinutes;
        @InvocableVariable(label='Total Estimated Minutes' description='Blended travel + wait score used for ranking.')
        public Decimal totalEstimatedMinutes;
    }

    public class Result {
        @InvocableVariable(label='Offices' description='DMV offices ranked best-first by total estimated time.')
        public List<OfficeOption> offices;
        @InvocableVariable(label='Found' description='Whether any eligible offices were found.')
        public Boolean found;
        @InvocableVariable(label='Message' description='Human-readable status, e.g. when no location or offices are available.')
        public String message;
    }

    @InvocableMethod(
        label='Find Optimal DMV Offices'
        description='Ranks appointment-eligible DMV offices for a service type by blended travel time and wait time for a given contact.'
    )
    public static List<Result> findOffices(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(handle(req));
        }
        return results;
    }

    private static Result handle(Request req) {
        Result res = new Result();
        res.offices = new List<OfficeOption>();
        res.found = false;

        // 1. Contact origin (populated upstream from ingested documents).
        Decimal originLat, originLng;
        for (Contact c : [
            SELECT MailingLatitude, MailingLongitude, MailingCity
            FROM Contact
            WHERE Id = :req.contactId
            LIMIT 1
        ]) {
            originLat = c.MailingLatitude;
            originLng = c.MailingLongitude;
        }
        if (originLat == null || originLng == null) {
            res.message = 'We don\'t have your location on file yet, so we can\'t rank offices by travel time. Please make sure your address is on record.';
            return res;
        }

        // 2. Latest wait reading per eligible office for the requested service.
        //    The DMO holds many timestamped readings; keep the newest per office.
        Map<String, OfficeOption> byOffice = new Map<String, OfficeOption>();
        for (Current_DMV_Wait_Times__dlm r : [
            SELECT office_id__c, office_name__c, city__c, region__c,
                   latitude__c, longitude__c, wait_minutes__c,
                   congestion_status__c, observed_at__c
            FROM Current_DMV_Wait_Times__dlm
            WHERE appointment_eligible__c = true
              AND service_type__c = :req.serviceType
            ORDER BY observed_at__c DESC
            LIMIT 2000
        ]) {
            if (r.office_id__c == null || byOffice.containsKey(r.office_id__c)) {
                continue; // first row per office is the newest (ordered desc)
            }
            OfficeOption o = new OfficeOption();
            o.officeId = r.office_id__c;
            o.officeName = r.office_name__c;
            o.city = r.city__c;
            o.region = r.region__c;
            o.latitude = r.latitude__c;
            o.longitude = r.longitude__c;
            o.expectedWaitMinutes = r.wait_minutes__c;
            o.congestionStatus = r.congestion_status__c;
            byOffice.put(r.office_id__c, o);
        }

        if (byOffice.isEmpty()) {
            res.message = 'No appointment-eligible DMV offices currently offer "' + req.serviceType + '".';
            return res;
        }

        List<OfficeOption> options = byOffice.values();

        // 3. Real drive times from Google Distance Matrix (one call, all destinations).
        Map<String, Decimal> travelByOffice = getTravelMinutes(originLat, originLng, options);

        // 4. Blend + rank.
        for (OfficeOption o : options) {
            o.estimatedTravelMinutes = travelByOffice.get(o.officeId);
            Decimal travel = (o.estimatedTravelMinutes == null) ? 999 : o.estimatedTravelMinutes;
            Decimal wait = (o.expectedWaitMinutes == null) ? 0 : o.expectedWaitMinutes;
            o.totalEstimatedMinutes = (travel * TRAVEL_WEIGHT) + (wait * WAIT_WEIGHT);
        }
        options.sort(new ByTotalMinutes());
        List<OfficeOption> top = new List<OfficeOption>();
        for (Integer i = 0; i < options.size() && i < MAX_OFFICES; i++) {
            top.add(options[i]);
        }

        res.offices = top;
        res.found = true;
        res.message = 'Found ' + top.size() + ' office(s), ranked by total estimated time.';
        return res;
    }

    /**
     * Calls Google Distance Matrix once with all office destinations.
     * Returns a map of officeId -> driving minutes. On any error, returns an
     * empty map (callers fall back to wait-only ranking).
     */
    private static Map<String, Decimal> getTravelMinutes(Decimal originLat, Decimal originLng, List<OfficeOption> options) {
        Map<String, Decimal> out = new Map<String, Decimal>();
        List<String> dests = new List<String>();
        List<String> orderedIds = new List<String>();
        for (OfficeOption o : options) {
            if (o.latitude != null && o.longitude != null) {
                dests.add(o.latitude + ',' + o.longitude);
                orderedIds.add(o.officeId);
            }
        }
        if (dests.isEmpty()) {
            return out;
        }
        // Google requires the key as a ?key= query param. Named Credentials can't
        // inject secrets into the URL, so read it from the DMV_Config CMT record.
        DMV_Config__mdt cfg = DMV_Config__mdt.getInstance('Google_Maps');
        String apiKey = (cfg != null) ? cfg.Api_Key__c : null;
        if (String.isBlank(apiKey)) {
            System.debug('DMV Maps API key not configured in DMV_Config__mdt.');
            return out;
        }
        try {
            HttpRequest httpReq = new HttpRequest();
            String path = '/maps/api/distancematrix/json'
                + '?origins=' + originLat + ',' + originLng
                + '&destinations=' + EncodingUtil.urlEncode(String.join(dests, '|'), 'UTF-8')
                + '&mode=driving'
                + '&key=' + apiKey;
            httpReq.setEndpoint('callout:DMV_Maps' + path);
            httpReq.setMethod('GET');
            httpReq.setTimeout(10000);

            HttpResponse resp = new Http().send(httpReq);
            if (resp.getStatusCode() != 200) {
                return out;
            }
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> rows = (List<Object>) body.get('rows');
            if (rows == null || rows.isEmpty()) {
                return out;
            }
            Map<String, Object> row0 = (Map<String, Object>) rows[0];
            List<Object> elements = (List<Object>) row0.get('elements');
            for (Integer i = 0; i < elements.size() && i < orderedIds.size(); i++) {
                Map<String, Object> el = (Map<String, Object>) elements[i];
                if (el.get('status') == 'OK') {
                    Map<String, Object> dur = (Map<String, Object>) el.get('duration');
                    Decimal seconds = (Decimal) dur.get('value');
                    out.put(orderedIds[i], (seconds / 60).setScale(1));
                }
            }
        } catch (Exception e) {
            // Swallow — ranking falls back to wait time only.
            System.debug('DMV Distance Matrix callout failed: ' + e.getMessage());
        }
        return out;
    }

    private class ByTotalMinutes implements Comparator<OfficeOption> {
        public Integer compare(OfficeOption a, OfficeOption b) {
            Decimal x = (a.totalEstimatedMinutes == null) ? 999999 : a.totalEstimatedMinutes;
            Decimal y = (b.totalEstimatedMinutes == null) ? 999999 : b.totalEstimatedMinutes;
            if (x < y) return -1;
            if (x > y) return 1;
            return 0;
        }
    }
}
