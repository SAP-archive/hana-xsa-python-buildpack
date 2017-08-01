$.response.contentType = "text/html";
var body = "";

body += "<html>\n";
body += "<head>\n";
body += "</head>\n";
body += "<body style=\"font-family: Tahoma, Geneva, sans-serif\">\n";
body += "<a href=\"sensors.xsodata/$metadata\" target=\"meta\">Metadata</a><br />\n";
body += "<a href=\"sensors.xsodata/?$format=json\" target=\"sdoc\">Service Doc</a><br />\n";
body += "<a href=\"sensors.xsodata/temp/?$top=5&$format=json\" target=\"5temps\">Top 5 Temps</a><br />\n";
body += "<a href=\"sensors.xsodata/temp(1)/?$format=json\" target=\"1temp\">First Temp</a><br />\n";
body += "<a href=\"sensors.xsodata/temp/?$format=json\" target=\"temps\">All Temps</a><br />\n";
body += "<a href=\"sensors.xsodata/temp/?$format=json&$filter=tempVal gt 99\" target=\"tempsf\">Temps > 99</a><br />\n";
body += "<a href=\"sensors.xsodata/temp/?$format=json&$filter=tempVal gt 99&$select=tempId,tempVal\" target=\"tempsnotime\">Temps > 99 no Time Fields</a><br />\n";
body += "<a href=\"test_post.xsjs\" target=\"post\">Post Temp</a><br />\n";
body += "</body>\n";
body += "</html>\n";

$.response.setBody(body);
