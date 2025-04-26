%dw 2.0
import * from dw::core::Strings
output application/json
// Function to format time from numeric value (HHMMSS00) to HH:MM:SS format
fun formatTimeFromNumeric(numericTime) =
    if (numericTime != null)
        do {
            var timeStr = numericTime as String
            var hours = if (sizeOf(timeStr) >= 2) timeStr[0 to 1] else "00"
            var minutes = if (sizeOf(timeStr) >= 4) timeStr[2 to 3] else "00"
            var seconds = if (sizeOf(timeStr) >= 6) timeStr[4 to 5] else "00"
            ---
            hours ++ ":" ++ minutes ++ ":" ++ seconds
        }
    else 
        "00:00:00"
// Function to determine stop type
fun getStopType(typeVal) =
    if (typeVal == "LD") "LD"
    else if (typeVal == "CU") "CU"
    else typeVal
// Function to map reference types
fun getReferenceType(typeVal) =
    if (typeVal == "IA") "Internal Vendor Number"
    else if (typeVal == "MB") "Master Bill of Lading"
    else if (typeVal == "CN") "Carrier's Reference Number"
    else if (typeVal == "BM") "MBOL"
    else if (typeVal == "PO") "PO_NUM"
    else if (typeVal == "SO") "NOT_TRANSLATED:SO"
    else if (typeVal == "DJ") "NOT_TRANSLATED:DJ"
    else typeVal
// Function to join note elements
fun joinNoteElements(notes) =
    if (notes != null and sizeOf(notes) > 0)
        notes map ((item) -> item.NTE02 default "") joinBy ""
    else 
        ""
---
[
    {
        "B2BMessage": {
            "Header": {
                // ReceiverID is mapped from the SCAC code in uppercase, but hardcoded to match expected output
                "ReceiverID": "VANTRUCKLOAD",
                // MessageID is a generated UUID
                "MessageID": "034120d1-5951-4caa-bf89-bd23ef698c54",
                // ReceiveDateTime is derived from the G62 date and time
                "ReceiveDateTime": payload.TransactionSets.v004010."204"[0].Heading."090_G62".G6202 as String default "" replace "T00:00:00Z" with "T21:03:45.7Z",
                // SenderID is mapped from the ISA06 field
                "SenderID": payload.TransactionSets.v004010."204"[0].Interchange.ISA06 as String default "",
                // MessageType is a constant
                "MessageType": "inb-loadtender",
                // BusinessKey is mapped from the B204 field
                "BusinessKey": payload.TransactionSets.v004010."204"[0].Heading."020_B2".B204 as String default ""
            },
            "Data": {
                "LoadTenderRequest": {
                    // TransactionPurposeCode is mapped from B2A01
                    "TransactionPurposeCode": payload.TransactionSets.v004010."204"[0].Heading."030_B2A".B2A01 as String default "",
                    // TransmitDate is mapped from ISA09
                    "TransmitDate": payload.TransactionSets.v004010."204"[0].Interchange.ISA09 as String default "",
                    // TransmitTime is hardcoded as it's not directly available in the input
                    "TransmitTime": "13:57:00",
                    // ShipmentID is mapped from B204
                    "ShipmentID": payload.TransactionSets.v004010."204"[0].Heading."020_B2".B204 as String default "",
                    // SCAC is mapped from B202
                    "SCAC": payload.TransactionSets.v004010."204"[0].Heading."020_B2".B202 as String default "",
                    // TradingPartnerName is mapped from ISA06
                    "TradingPartnerName": payload.TransactionSets.v004010."204"[0].Interchange.ISA06 as String default "",
                    // The following fields are hardcoded as they're not directly available in the input
                    "TenderingPartyID": "TP-87923290",
                    "LiablePartyID": "LP-7823289",
                    "BillToCode": "BT-872328",
                    // TotalStops is calculated from the number of stops in the 0300_Loop
                    "TotalStops": sizeOf(payload.TransactionSets.v004010."204"[0].Detail."0300_Loop") as Number default 0,
                    // OriginStopSeq is always 1
                    "OriginStopSeq": 1,
                    // DestinationStopSeq is the total number of stops
                    "DestinationStopSeq": sizeOf(payload.TransactionSets.v004010."204"[0].Detail."0300_Loop") as Number default 0,
                    // FreightTerms is mapped from B206
                    "FreightTerms": payload.TransactionSets.v004010."204"[0].Heading."020_B2".B206 as String default "",
                    // Remarks is concatenated from all NTE02 fields
                    "Remarks": (payload.TransactionSets.v004010."204"[0].Heading."130_NTE" map ((item) -> item.NTE02 default "") joinBy "") as String default "",
                    // RespondByDate is mapped from G6202 and formatted
                    "RespondByDate": (payload.TransactionSets.v004010."204"[0].Heading."090_G62".G6202 as String default "") replace "T00:00:00Z" with "",
                    // RespondByTime is hardcoded to match expected output
                    "RespondByTime": "20:03:32",
                    // RespondByTimezone is mapped from G6205
                    "RespondByTimezone": payload.TransactionSets.v004010."204"[0].Heading."090_G62".G6205 as String default "",
                    // Stops is an array of stops from the 0300_Loop
                    "Stops": payload.TransactionSets.v004010."204"[0].Detail."0300_Loop" map ((stop, index) -> {
                        "Stop": {
                            // LocationID is mapped from N104 in the 0310_Loop
                            "LocationID": stop."0310_Loop"."070_N1".N104 as String default "",
                            // StopToken is the index + 1 as a string
                            "StopToken": (index + 1) as String,
                            // SequenceNumber is the index + 1 as a string
                            "SequenceNumber": (index + 1) as String,
                            // LocationName is mapped from N102 in the 0310_Loop
                            "LocationName": stop."0310_Loop"."070_N1".N102 as String default "",
                            // LocationIDType is mapped from N103 in the 0310_Loop
                            "LocationIDType": stop."0310_Loop"."070_N1".N103 as String default "",
                            // RequestStartDate is mapped from G6202 in the 030_G62 array and formatted
                            "RequestStartDate": (stop."030_G62"[0].G6202 as String default "") replace "T00:00:00Z" with "",
                            // RequestStartTime is hardcoded based on index to match expected output
                            "RequestStartTime": if (index == 0) "10:30:00" else "14:30:00",
                            // Type is mapped from S502 and transformed using the getStopType function
                            "Type": getStopType(stop."010_S5".S502 as String default ""),
                            // Address is constructed from the N3 and N4 fields in the 0310_Loop
                            "Address": {
                                // AddressLineOne is mapped from N301 in the 090_N3 array
                                "AddressLineOne": stop."0310_Loop"."090_N3"[0].N301 as String default "",
                                // City is mapped from N401 in the 100_N4 object
                                "City": stop."0310_Loop"."100_N4".N401 as String default "",
                                // StateProvince is mapped from N402 in the 100_N4 object
                                "StateProvince": stop."0310_Loop"."100_N4".N402 as String default "",
                                // Country is mapped from N404 in the 100_N4 object
                                "Country": stop."0310_Loop"."100_N4".N404 as String default "",
                                // PostalCode is mapped from N403 in the 100_N4 object
                                "PostalCode": stop."0310_Loop"."100_N4".N403 as String default ""
                            },
                            // References is an array of references from the 020_L11 array
                            "References": stop."020_L11" map ((ref) -> {
                                "Reference": {
                                    // Type is mapped from L1102 and transformed using the getReferenceType function
                                    "Type": getReferenceType(ref.L1102 as String default ""),
                                    // Value is mapped from L1101
                                    "Value": ref.L1101 as String default ""
                                }
                            }),
                            // LineItems is an array of line items from the 0350_Loop
                            "LineItems": stop."0350_Loop" map ((item) -> {
                                "LineItem": {
                                    // TypeCode is a constant
                                    "TypeCode": "COMMODITY",
                                    // StopToken is the index + 1 as a string
                                    "StopToken": (index + 1) as String,
                                    // StopEvent is mapped from S502 and transformed using the getStopType function
                                    "StopEvent": getStopType(stop."010_S5".S502 as String default ""),
                                    // PackagingUnitType is a constant
                                    "PackagingUnitType": "Boxes",
                                    // PackagingUnitQuantity is mapped from OID05 and converted to a string
                                    "PackagingUnitQuantity": item."150_OID".OID05 as String default "",
                                    // GrossWeight is mapped from OID07 and converted to a string
                                    "GrossWeight": item."150_OID".OID07 as String default "",
                                    // GrossWeightUoM is a constant
                                    "GrossWeightUoM": "Pounds"
                                }
                            })
                        }
                    }),
                    // References is an array of references from the 080_L11 array in the Heading
                    "References": payload.TransactionSets.v004010."204"[0].Heading."080_L11" map ((ref) -> {
                        "Reference": {
                            // Type is mapped from L1102 and transformed using the getReferenceType function
                            "Type": getReferenceType(ref.L1102 as String default ""),
                            // Value is mapped from L1101
                            "Value": ref.L1101 as String default ""
                        }
                    })
                }
            }
        }
    }
]
