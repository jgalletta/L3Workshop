/**
 * Generic value wrapper for a single Document AI extracted field.
 * Doc AI returns each field as an object { "value": ..., "confidence": ... };
 * this mirrors that shape so typed schema classes can bind parsedData.<field>.value.
 */
public class L3_DocAI_Field {
    @AuraEnabled public String value;
    @AuraEnabled public Decimal confidence;
}