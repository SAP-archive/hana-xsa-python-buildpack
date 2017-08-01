// $.import("mta_iot.js","crudCommon");
//$.import("crudCommon.xsjslib");


// Following logic from Thomas Jung
// http://scn.sap.com/thread/3447784

/**
@function Escape Special Characters in JSON strings
@param {string} input - Input String
@returns {string} the same string as the input but now escaped
*/
function escapeSpecialChars(input) {
          if(typeof(input) != 'undefined' && input != null)
          {
          return input
    .replace(/[\\]/g, '\\\\')
    .replace(/[\"]/g, '\\\"')
    .replace(/[\/]/g, '\\/')
    .replace(/[\b]/g, '\\b')
    .replace(/[\f]/g, '\\f')
    .replace(/[\n]/g, '\\n')
    .replace(/[\r]/g, '\\r')
    .replace(/[\t]/g, '\\t'); }
          else{
 
                    return "";
          }
}


/**
@function Converts any XSJS RecordSet object to a JSON Object
@param {object} rs - XSJS Record Set object
@param {optional String} rsName - name of the record set object in the JSON
@returns {object} JSON representation of the record set data
*/
function recordSetToJSON(rs,rsName){
          rsName = typeof rsName !== 'undefined' ? rsName : 'entries';
 
          var meta = rs.getMetaData();
          var colCount = meta.getColumnCount();
          var values=[];
          var table=[];
          var value="";
          while (rs.next()) {
          for (var i=1; i<=colCount; i++) {
                    value = '"'+meta.getColumnLabel(i)+'" : ';
               switch(meta.getColumnType(i)) {
               case $.db.types.VARCHAR:
               case $.db.types.CHAR:
                    value += '"'+ escapeSpecialChars(rs.getString(i))+'"';
                    break;
               case $.db.types.NVARCHAR:
               case $.db.types.NCHAR:
               case $.db.types.SHORTTEXT:
                    value += '"'+escapeSpecialChars(rs.getNString(i))+'"';
                    break;
               case $.db.types.TINYINT:
               case $.db.types.SMALLINT:
               case $.db.types.INT:
               case $.db.types.BIGINT:
                    value += rs.getInteger(i);
                    break;
               case $.db.types.DOUBLE:
                    value += rs.getDouble(i);
                    break;
               case $.db.types.DECIMAL:
                    value += rs.getDecimal(i);
                    break;
               case $.db.types.REAL:
                    value += rs.getReal(i);
                    break;
               case $.db.types.NCLOB:
               case $.db.types.TEXT:
                    value += '"'+ escapeSpecialChars(rs.getNClob(i))+'"';
                    break;
               case $.db.types.CLOB:
                    value += '"'+ escapeSpecialChars(rs.getClob(i))+'"';
                    break;                   
               case $.db.types.BLOB:
                          value += '"'+ $.util.convert.encodeBase64(rs.getBlob(i))+'"';
                    break;                   
               case $.db.types.DATE:
                    value += '"'+rs.getDate(i)+'"';
                    break;
               case $.db.types.TIME:
                    value += '"'+rs.getTime(i)+'"';
                    break;
               case $.db.types.TIMESTAMP:
                    value += '"' + (rs.getTimestamp(i)).getTime() + '"';
                    break;
               case $.db.types.SECONDDATE:
                    value += '"'+rs.getSeconddate(i)+'"';
                    break;
               default:
                    value += '"'+escapeSpecialChars(rs.getString(i))+'"';
               }
               values.push(value);
               }
             table.push('{'+values+'}');
          }
          return           JSON.parse('{"'+ rsName +'" : [' + table          +']}');
 
}

/**
 * @param {connection} Connection - The SQL connection used in the OData request
 * @param {beforeTableName} String - The name of a temporary table with the single entyr before the operation  (UPDATE and DELETE events only)
 * @param {afterTableName} String - The name of a temporary table with the single entry after the operation (CREATE and UPDATE events only)
**/


function tempCreate(param) {
    var after = param.afterTableName;
    
    //Get Input New Record Values
    var pStmt = param.connection.prepareStatement('select * from "' + after + '"');
    var Data = recordSetToJSON(pStmt.executeQuery(), 'Details');
    pStmt.close();
   
// 01 "tempId" INTEGER CS_INT NOT NULL , 
// 02 "tempVal" INTEGER CS_INT NOT NULL , 
// 03 "ts" LONGDATE CS_LONGDATE NOT NULL , 
// 04 "created" LONGDATE CS_LONGDATE NOT NULL , 

    
    var field1 = parseInt(Data.Details[0].tempId);
    
    var field2 = parseInt(Data.Details[0].tempVal);

    var field3 = Data.Details[0].ts;
    var ts3,date3,tsmo3,tsda3,tshr3,tsmin3,tssec3,tsmils3;
    if (field3 !== "null") {
    	//var d = new Date("2015-03-25T12:00:00.123");
        date3 = new Date(parseInt(field3));  
        tsmo3 = date3.getMonth() + 1;
        if (tsmo3 <= 9) { tsmo3 = "0" + tsmo3; } else { tsmo3 = "" + tsmo3; }
        tsda3 = date3.getDate();
        if (tsda3 <= 9) { tsda3 = "0" + tsda3; } else { tsda3 = "" + tsda3; }
        
        tshr3 = date3.getHours();
        if (tshr3 <= 9) { tshr3 = "0" + tshr3; } else { tshr3 = "" + tshr3; }
        tsmin3 = date3.getMinutes();
        if (tsmin3 <= 9) { tsmin3 = "0" + tsmin3; } else { tsmin3 = "" + tsmin3; }
        tssec3 = date3.getSeconds();
        if (tssec3 <= 9) { tssec3 = "0" + tssec3; } else { tssec3 = "" + tssec3; }
        tsmils3 = date3.getMilliseconds();
        if (tsmils3 <= 9) { tsmils3 = "00" + tsmils3; } 
        else if ((9 < tsmils3) && (tsmils3 <= 99)) { tsmils3 = "0" + tsmils3; } 
        else { tsmils3 = "" + tsmils3; }
        
        ts3 = date3.getFullYear() + "-" + tsmo3 + "-" + tsda3 + " " + tshr3 + ":" + tsmin3 + ":" + tssec3 + "." + tsmils3;
    }
    else {
        ts3 = "null"; 
    }


    //Validate Parameters
    // if (!validateField4Empty(field4)) {
    //     throw 'Invalid direction for ' + field4 + '';
    // }

    //Get Next Sequence Number
    pStmt = param.connection.prepareStatement('select "tempId".NEXTVAL from dummy');
    var rs = pStmt.executeQuery();
    var seqNo = '';
    while (rs.next()) {
        seqNo = rs.getString(1);
    }
    pStmt.close();
    
    for (var i=0; i<2; i++) {
        //var pStmt;
        //insert into "IOT"."iot.data::sensors.temp" values("iot.data::tempId".NEXTVAL,100,TO_TIMESTAMP ('2016-02-02 13:23:45.678', 'YYYY-MM-DD HH24:MI:SS.FF3'),CURRENT_UTCTIMESTAMP);

        if (i<1) {
            pStmt = param.connection.prepareStatement('insert into "sensors.temp" values(?,?,TO_TIMESTAMP (?, \'YYYY-MM-DD HH24:MI:SS.FF3\'),CURRENT_UTCTIMESTAMP)');
        }
        else {
            pStmt = param.connection.prepareStatement('TRUNCATE TABLE "' + after + '" ');
            pStmt.executeUpdate();
            pStmt.close();
            
            pStmt = param.connection.prepareStatement('insert into "' + after + '" values(?,?,TO_TIMESTAMP (?, \'YYYY-MM-DD HH24:MI:SS.FF3\'),CURRENT_UTCTIMESTAMP)');
        }
        
        pStmt.setInteger(1, parseInt(seqNo));
        
        pStmt.setInteger(2, field2);

        if (ts3 === "null") { pStmt.setNull(3); } else { pStmt.setString(3, ts3); }
        
        pStmt.executeUpdate();
        pStmt.close();
    }
}

function validateField4Empty(the_field) {
    if (the_field === '') {
        return false;
    }
    else {
        return true;
    }
}


