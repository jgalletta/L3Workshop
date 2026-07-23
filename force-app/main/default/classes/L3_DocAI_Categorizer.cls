/**
 * Categorizes a document as 'Passport', 'Power Bill', or 'Other'.
 *
 * Primary path: an Einstein prompt template / LLM classifies from the extracted field JSON.
 * Fallback path: deterministic classification from which fields came back populated
 * (passport -> name/dateOfBirth; powerBill -> address). Used if generative AI is
 * unavailable or errors, so the pipeline never hard-fails on the LLM leg.
 *
 * NOTE: the LLM call in classifyWithLlm() is filled in once the exact ConnectApi
 * signature is confirmed; until then it throws and we fall back to deterministic.
 */
public class L3_DocAI_Categorizer {

    public static final String PASSPORT = 'Passport';
    public static final String POWER_BILL = 'Power Bill';
    public static final String OTHER = 'Other';

    /**
     * @param passportJson  extracted-data JSON when run through the passport config
     * @param billJson      extracted-data JSON when run through the powerBill config
     */
    public static String categorize(String passportJson, String billJson) {
        try {
            String llmVerdict = classifyWithLlm(passportJson, billJson);
            if (String.isNotBlank(llmVerdict)) {
                return normalizeVerdict(llmVerdict);
            }
        } catch (Exception e) {
            System.debug('LLM categorize failed, falling back: ' + e.getMessage());
        }
        return classifyDeterministic(passportJson, billJson);
    }

    private static String normalizeVerdict(String raw) {
        String v = raw.toLowerCase();
        if (v.contains('passport')) return PASSPORT;
        if (v.contains('power') || v.contains('bill') || v.contains('utility')) return POWER_BILL;
        return OTHER;
    }

    /** Deterministic fallback: inspect which schema fields have non-empty values. */
    private static String classifyDeterministic(String passportJson, String billJson) {
        Boolean hasPassportFields = jsonHasValue(passportJson, new List<String>{ 'name', 'dateOfBirth' });
        Boolean hasBillFields = jsonHasValue(billJson, new List<String>{ 'address' });
        if (hasPassportFields && !hasBillFields) return PASSPORT;
        if (hasBillFields && !hasPassportFields) return POWER_BILL;
        // If both or neither populated, prefer the one with more populated fields.
        if (hasPassportFields && hasBillFields) return PASSPORT;
        return OTHER;
    }

    private static Boolean jsonHasValue(String extractedJson, List<String> keys) {
        if (String.isBlank(extractedJson)) return false;
        try {
            String normalized = normalizeExtracted(extractedJson);
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(normalized);
            for (String k : keys) {
                Object field = m.get(k);
                if (field instanceof Map<String, Object>) {
                    Object val = ((Map<String, Object>) field).get('value');
                    if (val != null && String.valueOf(val).trim().length() > 0) return true;
                }
            }
        } catch (Exception e) {
            return false;
        }
        return false;
    }

    /** Unwrap the [{data:"<escaped json>"}] shape Doc AI returns, if present. */
    private static String normalizeExtracted(String input) {
        Object parsed = JSON.deserializeUntyped(input);
        if (parsed instanceof List<Object>) {
            List<Object> arr = (List<Object>) parsed;
            if (!arr.isEmpty() && arr[0] instanceof Map<String, Object>) {
                Object dataVal = ((Map<String, Object>) arr[0]).get('data');
                if (dataVal instanceof String) return ((String) dataVal).unescapeHtml4();
            }
        }
        return input;
    }

    private static final String TEMPLATE_DEV_NAME = 'L3_DocAI_Document_Classifier';

    /** Invoke the GenAiPromptTemplate classifier and return its generated text. */
    private static String classifyWithLlm(String passportJson, String billJson) {
        ConnectApi.EinsteinPromptTemplateGenerationsInput input =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.isPreview = false;

        Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>();
        ConnectApi.WrappedValue passportVal = new ConnectApi.WrappedValue();
        passportVal.value = String.isBlank(passportJson) ? '(no data)' : passportJson;
        params.put('Input:PassportJson', passportVal);

        ConnectApi.WrappedValue billVal = new ConnectApi.WrappedValue();
        billVal.value = String.isBlank(billJson) ? '(no data)' : billJson;
        params.put('Input:PowerBillJson', billVal);

        input.inputParams = params;
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        // Must be an existing registered AI application; this is the documented
        // default for template-invoked generations.
        input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_DEV_NAME, input);

        if (output != null && output.generations != null && !output.generations.isEmpty()) {
            return output.generations[0].text;
        }
        return null;
    }
}