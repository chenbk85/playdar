/*
 Created on 28/02/2009
 Copyright 2009 Max Howell <mxcl@users.sf.net>
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


//TODO watch exit code of playdard (if early exits), and watch process while pref pane is open
// ^^ important in case playdard exits immediately due to crash or somesuch

//TODO remember path that we scanned with defaults controller
//TODO memory leaks
//TODO log that stupid exception
//TODO sparkle updates
// ^^ ensure if prefpane is updated, it restarts playdard
//TODO start at login checkbox


#import "main.h"
#include <sys/sysctl.h>
#include <Sparkle/SUUpdater.h>


static pid_t playdard_pid()
{
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    struct kinfo_proc *info;
    size_t N;
    pid_t pid = 0;
    
    if(sysctl(mib, 3, NULL, &N, NULL, 0) < 0)
        return 0; //wrong but unlikely
    if(!(info = NSZoneMalloc(NULL, N)))
        return 0; //wrong but unlikely
    if(sysctl(mib, 3, info, &N, NULL, 0) < 0)
        goto end;

    N = N / sizeof(struct kinfo_proc);
    for(size_t i = 0; i < N; i++)
        if(strcmp(info[i].kp_proc.p_comm, "playdard") == 0)
            { pid = info[i].kp_proc.p_pid; break; }
end:
    NSZoneFree(NULL, info);
    return pid;
}


static inline NSString* iniPath()
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/org.playdar.ini"];
}

static inline NSString* collectionDbPath()
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Playdar/collection.db"];
}

static inline NSString* fullname()
{
    // being cautious
    NSString* fullname = NSFullUserName();
    return (fullname && [fullname length] > 0) ? fullname : NSUserName();
}


@implementation OrgPlaydarPreferencePane

-(void)mainViewDidLoad
{
    [SUUpdater updaterForBundle:[self bundle]];
    
    NSString* ini = iniPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:ini] == false)
    {
        NSArray* args = [NSArray arrayWithObjects: fullname(), collectionDbPath(), ini, nil];
        [self exec:@"playdar.ini.rb" withArgs:args];
    }

    NSString* home = NSHomeDirectory();
    [popup addItemWithTitle: [home stringByAppendingPathComponent:@"Music"]];
    [popup addItemWithTitle: home];
    [[popup menu] addItem:[NSMenuItem separatorItem]];
    [[[popup menu] addItemWithTitle:@"Select..." action:@selector(select:) keyEquivalent:@""] setTarget:self];
    
    if (pid = playdard_pid()) [start setTitle:@"Stop Playdar"];
}
 
-(void)onScan:(id)sender
{
    NSArray* args = [NSArray arrayWithObjects:[popup titleOfSelectedItem], collectionDbPath(), nil];
    [self exec:@"scan.sh" withArgs:args];
}

-(void)onStart:(id)sender
{
    if(pid) 
    {
        if(kill( pid, SIGKILL ) != 0) return;
        pid = 0;
        [start setTitle:@"Start Playdar"];
    }
    else
    {
        NSArray* args = [NSArray arrayWithObjects:@"-c", iniPath(), nil];
        pid = [self exec:@"../MacOS/playdard" withArgs:args];
        if (pid) [start setTitle:@"Stop Playdar"];
    }
}

////// Directory selector
-(void)select:(id)sender
{
    if ([popup indexOfSelectedItem] != [popup numberOfItems]-1) return;
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    
    [panel beginSheetForDirectory:nil 
                             file:nil 
                   modalForWindow:[[self mainView] window]
                    modalDelegate:self 
                   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
                      contextInfo:nil];
}

-(void)openPanelDidEnd:(NSOpenPanel*)panel
            returnCode:(int)returnCode
           contextInfo:(void*)contextInfo 
{
    if (returnCode == NSOKButton) {
        int const index = [[popup menu] numberOfItems]-2;
        [popup insertItemWithTitle:[panel filename] 
                           atIndex:index];
        [popup selectItemAtIndex: index];
    }
    else
        [popup selectItemAtIndex:0];
}
////// Directory selectors


-(int)exec:(NSString*)command
   withArgs:(NSArray*)args
{
    @try {
        NSString* resources = [[self bundle] resourcePath];
        NSString* path = [resources stringByAppendingPathComponent:command];
        
        NSTask *task = [[NSTask alloc] init];
        [task setCurrentDirectoryPath:resources];
        [task setLaunchPath:path];
        [task setArguments:args];
        [task launch];
        return [task processIdentifier];
    }
    @catch (NSException* e)
    {
        //TODO log - couldn't figure out easy way to do this
        return 0;
    }
}

@end
