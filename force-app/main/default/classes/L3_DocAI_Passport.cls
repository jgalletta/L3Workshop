/**
 * Typed schema for the 'passport' IDP config.
 * Property names MUST exactly match the config schemaConfig keys (name, dateOfBirth);
 * the Flow result screen binds parsedData.<field>.value.
 */
public class L3_DocAI_Passport {
    @AuraEnabled public L3_DocAI_Field name;
    @AuraEnabled public L3_DocAI_Field dateOfBirth;
}