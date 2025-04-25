%dw 2.0
output application/json
//var custShipId = payload.TransactionSets.v004010."204".Heading."020_B2".B204[0]

var shipmentId = payload.TransactionSets.v004010."204".Heading."020_B2".B204[0]
var partnerId = payload.TransactionSets.v004010."204".Group.GS02[0] default "UNKNOWN"

var currentTimePST = now() >> ("US/Pacific" as TimeZone)

//Retrieve Customer profile information
var partnerOrderProfile = readUrl("https://b2b-mythical-3-lookups.us-e2.cloudhub.io/lookup/tms-customer-profile?partnerId=" ++ partnerId)

//Retrieve partner specific and default reference type translation rules
var refereneTypeXlate = readUrl("https://b2b-mythical-3-lookups.us-e2.cloudhub.io/lookup/in-ref-xlate?partnerId=" ++ partnerId)

// Check for partner specific reference type translation, if not found - apply default reference type translation
fun xlateRefType(fromRefType) = {
	toRefType: refereneTypeXlate.response.partnerReferences[?($.PARTNER_REF_TYPE == fromRefType)][0].MYTHICAL_REF_TYPE 
	        default refereneTypeXlate.response.defaultReferences[?($.PARTNER_REF_TYPE == fromRefType)][0].MYTHICAL_REF_TYPE
}

var packageUnitTypeCodes = [
    {
        ediCode: "CA",
        appCode: "Boxes"
    },
    {
        ediCode: "EA",
        appCode: "Each"
    }
]

var uomCodes = [
    {
        ediCode: "L",
        appCode: "Pounds"
    },
    {
        ediCode: "K",
        appCode: "Kilograms"
    }
]

---
payload.TransactionSets.v004010."204" map ( v204 , indexOfV204 ) -> {
	B2BMessage: {
		Header: {
			ReceiverID: if(v204.Group.GS03 == "MBLK") "BULK" else if(v204.Group.GS03 == "MIMD") "INTERMODAL" else if(v204.Group.GS03 == "MVTL") "VANTRUCKLOAD" else "UNKNOWN",
			MessageID: vars.b2bMessageContext.messageId default v204.Interchange.ISA13 as String,
			ReceiveDateTime: now() as String,
			SenderID: v204.Group.GS02 default "",
			MessageType: "inb-loadtender",
			BusinessKey: v204.Heading."020_B2".B204 default "UNKNOWN"
		},
		Data: {
			LoadTenderRequest: {
				TransactionPurposeCode: v204.Heading."030_B2A".B2A01 default "",
				TransmitDate: v204.Interchange.ISA09 as String {format: "yyyy-MM-dd"} default "",
				TransmitTime: (v204.Interchange.ISA10/1000) as DateTime as String {format:"HH:mm:ss"} default "",
				ShipmentID: v204.Heading."020_B2".B204 default "",
				SCAC: v204.Heading."020_B2".B202 default "",
				TradingPartnerName: v204.Group.GS02 default "",
				//TenderingPartyID: v204.Group.GS02 default "",
				//LiablePartyID: v204.Group.GS02 default "",
				//Map TENDERING_PARTY_ID from lookup
				TenderingPartyID: if ( partnerOrderProfile.executionStatus == "true" and partnerOrderProfile.responseFound == "true" ) 
				              partnerOrderProfile.response.TENDERING_PARTY_ID else "NOT_FOUND",
				//Map LIABLE_PARTY_ID from lookup
				LiablePartyID: if ( partnerOrderProfile.executionStatus == "true" and partnerOrderProfile.responseFound == "true" ) 
				              partnerOrderProfile.response.LIABLE_PARTY_ID else "NOT_FOUND",
				//Map BILL_TO_ID from lookup
				BillToCode: if ( partnerOrderProfile.executionStatus == "true" and partnerOrderProfile.responseFound == "true" ) 
				               partnerOrderProfile.response.BILL_TO_ID else "NOT_FOUND",
				TotalStops: sizeOf(v204.Detail."0300_Loop"."010_S5"),
				OriginStopSeq: v204.Detail."0300_Loop"."010_S5".S501[0],
				DestinationStopSeq: v204.Detail."0300_Loop"."010_S5".S501[sizeOf(v204.Detail."0300_Loop"."010_S5") - 1],
				FreightTerms: v204.Heading."020_B2".B206 default "",
				Remarks: v204.Heading."130_NTE".NTE02[0] ++ v204.Heading."130_NTE".NTE02[1] default "",
				
				RespondByDate: if (v204.Heading."090_G62".G6201 == "64" ) v204.Heading."090_G62".G6202 as Date as String {format: "yyyy-MM-dd"} else (currentTimePST + |PT2H|) as String {format: "yyyy-MM-dd"},
				RespondByTime: if (v204.Heading."090_G62".G6201 == "64" ) (v204.Heading."090_G62".G6204/1000) as DateTime as String {format:"HH:mm:ss"} else (currentTimePST + |PT2H|) as String {format:"HH:mm:ss"},
				RespondByTimezone: if ( v204.Heading."090_G62".G6201 == "64" ) v204.Heading."090_G62".G6205 else "PT",
				Stops: v204.Detail."0300_Loop" map ( v0300Loop , indexOfV0300Loop ) -> {
					Stop: {
						LocationID: v0300Loop."0310_Loop"."070_N1".N104 default "",
						StopToken: v0300Loop."010_S5".S501 as String default "",
						SequenceNumber: v0300Loop."010_S5".S501 as String default "",
						LocationName: v0300Loop."0310_Loop"."070_N1".N102 default "",
						LocationIDType: v0300Loop."0310_Loop"."070_N1".N103 default "",
						RequestStartDate: v0300Loop."030_G62".G6202[0] as Date as String {format: "yyyy-MM-dd"} default "",
						RequestStartTime: (v0300Loop."030_G62".G6204[0]/1000) as DateTime as String {format:"HH:mm:ss"} default "",
						Type: v0300Loop."010_S5".S502 default "",
						Address: {
							AddressLineOne: v0300Loop."0310_Loop"."090_N3".N301[0] default "",
							City: v0300Loop."0310_Loop"."100_N4".N401 default "",
							StateProvince: v0300Loop."0310_Loop"."100_N4".N402 default "",
							Country: v0300Loop."0310_Loop"."100_N4".N404 default "",
							PostalCode: v0300Loop."0310_Loop"."100_N4".N403 default ""
						},
						References: v0300Loop."020_L11" map ( v020L11 , indexOfV020L11 ) -> {
							Reference: {
								//Type: v020L11.L1102 default "",
								Type: xlateRefType(v020L11.L1102).toRefType default ("NOT_TRANSLATED:" ++ (v020L11.L1102 default "")),
								Value: v020L11.L1101 default ""
							}
						},
						LineItems: v0300Loop."0350_Loop" map ( v0350Loop , indexOfV0350Loop ) -> {
							LineItem: {
								TypeCode: "COMMODITY",
								StopToken: v0300Loop."010_S5".S501 as String default "",
								StopEvent: v0300Loop."010_S5".S502 default "",
								PackagingUnitType: packageUnitTypeCodes[?$.ediCode == v0350Loop."150_OID".OID04][0].appCode default "Each",
								PackagingUnitQuantity: v0350Loop."150_OID".OID05 as String default "",
								GrossWeight: v0350Loop."150_OID".OID07 as String default "",
								GrossWeightUoM: uomCodes[?$.ediCode == v0350Loop."150_OID".OID06][0].appCode default "Pounds"
							}
						}
					}
				},
				References: v204.Heading."080_L11" map ( v080L11 , indexOfV080L11 ) -> {
					Reference: {
						//Type: v080L11.L1102 default "",
						Type: xlateRefType(v080L11.L1102).toRefType default ("NOT_TRANSLATED:" ++ (v080L11.L1102 default "")),
						Value: v080L11.L1101 default ""
					}
				}
			}
		}
	}
}