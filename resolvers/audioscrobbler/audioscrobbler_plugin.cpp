#include "audioscrobbler_plugin.h"
#include "scrobsub.h"

using playdar::plugin::audioscrobbler;
static audioscrobbler* instance = 0;


void
audioscrobbler::scrobsub_callback(int e, const char*s)
{
    if (e == SCROBSUB_AUTH_REQUIRED && !instance->auth_required)
    {
        instance->auth_required = true;
        cout << "You need to authenticate scrobbling, visit http://localhost:8888/audioscrobbler/config/" << endl;
    }
}

bool
audioscrobbler::init(playdar::Config* c, Resolver* r)
{
    if(instance) return false; //loading more than one scrobbling plugin is stupid
    instance = this;
    
    ResolverService::init(c, r);
    scrobsub_init(scrobsub_callback);
    return true;
}

void
audioscrobbler::Destroy()
{
    scrobsub_stop();
    instance = 0;
}

static void start(const playdar_request& rq)
{
    #define GET(x) rq.getvar_exists(x) ? rq.getvar(x).c_str() : ""
    
    const char* artist = GET("a");
    const char* track = GET("t");
    const char* source = GET("o");
    const char* album = GET("b");
    const char* mbid = GET("m");
    uint duration = atoi(GET("l")); // zero on error, which scrobsub will reject, so all good
    uint track_number = atoi(GET("n"));

    scrobsub_start(artist, track, album, duration, track_number, mbid);
}

static string config(bool auth_required)
{
    if (!auth_required || scrobsub_finish_auth())
        return "<p>Playdar is authorized to <a href='http://www.last.fm/help/faq?category=Scrobbling'>scrobble</a>. "
               "To revoke, visit <a href='http://www.last.fm/settings/applications'>Last.fm</a>.</p>";
    
    char url[110];
    scrobsub_auth(url);
    return string("<p>You need to <a href='") + url + "'>authenticate</a> in order to scrobble.</p>";
}

string
audioscrobbler::http_handler(const playdar_request& rq, playdar::auth* pauth)
{
    if(rq.parts().size()<2) return "Hi index!";
    string action = rq.parts()[1];
    if(action == "start")  { start(rq); return "OK"; }
    if(action == "pause")  { scrobsub_pause(); return "OK"; }
    if(action == "resume") { scrobsub_resume(); return "OK"; }
    if(action == "stop")   { scrobsub_stop(); return "OK"; }
    
    if(action == "config") return config(auth_required);
    
    return "Unhandled"; // --warning
}


EXPORT_DYNAMIC_CLASS( audioscrobbler )