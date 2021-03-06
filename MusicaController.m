//
//  MusicaController.m
//  Musica
//
//  Created by Chloe Stars on 9/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MusicaController.h"
#import "Track.h"
#import "NSImage+Resize.h"
#import "ThemeLoader.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation MusicaController

@synthesize window;
@synthesize preferencesController;

#pragma mark -

-(id)init {
    self = [super init];
	if (self) {
		#ifndef DEBUG
		NSLog(@"MusicaController compiled as RELEASE");
		// First run code. Set default settings here
		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"musicaFirstRun"]) {
			[[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"musicaEnableNotifications"];
			[[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"musicaFirstRun"];
		}
		#else
		NSLog(@"MusicaController compiled as DEBUG");
		#endif
		// Load in menu bar mode if that's what we chose
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaMenuBar"]) {
			NSLog(@"MusicaController Menu bar should be loading.");
			NSStatusBar *bar = [NSStatusBar systemStatusBar];
			
			theItem = [bar statusItemWithLength:NSVariableStatusItemLength];
            
			//TrayMenu *menu = [[TrayMenu alloc] init];
            menu = [[TrayMenu alloc] init];
			
            NSImage *menuImage = [NSImage imageNamed:@"trayIcon"];
            [menuImage setTemplate:YES];
            
			[theItem setImage:menuImage];
			//[theItem setAlternateImage:[NSImage imageNamed:@"trayIconPressed"]];
			[theItem setHighlightMode:YES];
			[theItem setMenu:[menu createMenu]];
		}
		else {
			// this should be called from the application delegate's applicationDidFinishLaunching
			// method or from some controller object's awakeFromNib method
			if (![[NSUserDefaults standardUserDefaults] boolForKey:@"LaunchAsAgentApp"]) {
				ProcessSerialNumber psn = { 0, kCurrentProcess };
				// display dock icon
				TransformProcessType(&psn, kProcessTransformToForegroundApplication);
				// enable menu bar
				SetSystemUIMode(kUIModeNormal, 0);
				// switch to Dock.app
				[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.dock" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:nil];
				// switch back
				[[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
			}
		}
	}
	return self;
}

- (void)fadeOut:(NSTimer *)theTimer
{
    if ([window alphaValue] > 0.0) {
        // If window is still partially opaque, reduce its opacity.
        [window setAlphaValue:[window alphaValue] - 0.2];
    } else {
        // Otherwise, if window is completely transparent, destroy the timer and close the window.
        [fadeOutTimer invalidate];
        fadeOutTimer = nil;
        
        //[window close];
        
        //Hide the window because iTunes is no longer running
        [window orderOut:nil];
        
        // Make the window fully opaque again for next time.
        //[window setAlphaValue:1.0];
    }
}

-(void)applicationWillTerminate:(id)sender
{
	NSLog(@"MusicaController Quitting now");
	[self storeWindowPosition];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaMenuBar"]) {
		[[NSStatusBar systemStatusBar] removeStatusItem: theItem];
	}
}

#pragma mark -
#pragma mark Prepare Application

-(void)awakeFromNib
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadTheme) name:@"loadTheme" object:nil];
	
	// Give us features we need that EyeTunes doesn't
	//iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    Instacast = [SBApplication applicationWithBundleIdentifier:@"com.vemedio.osx.Instacast"];
    Radium = [SBApplication applicationWithBundleIdentifier:@"com.catpigstudios.Radium3"];
    Rdio = [SBApplication applicationWithBundleIdentifier:@"com.rdio.desktop"];
    Spotify = [SBApplication applicationWithBundleIdentifier:@"com.spotify.client"];
    Vox = [SBApplication applicationWithBundleIdentifier:@"com.coppertino.Vox"];
	
	bowtie = [[Bowtie alloc] init];
	[bowtie setWindow:window];
	
	// hijack the xib's webView and replace it with our own
	/*MovableWebFrameView *webFrameView = [[MovableWebFrameView alloc] initWithFrame:webView.frame];
	//WebFrame *webFrame = [webFrameView webFrame];
	for (NSView *view in [webView subviews]) {
		if ([[view className] isEqualToString:@"WebFrameView"]) {
			[webView addSubview:webFrameView positioned:NSWindowAbove relativeTo:view];
			[view removeFromSuperview];
		}
	}*/
	
	webView.wantsLayer = YES;
	webView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
	[[[webView mainFrame] frameView] setAllowsScrolling:NO];
	[webView setDrawsBackground:NO];
	[webView setFrameLoadDelegate:self];
	[webView setUIDelegate:self];
	[webView setEditingDelegate:self];
	
	[window setOpaque:NO];
	[window setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];  //Tells the window to use a transparent colour.
	//[webView setFrame:frame];
	//[window center];
	player = [[Player alloc] init];
	
	NSLog(@"MusicaController Awoken from Nib");
	// Begin the fadeIn
	//[window setAlphaValue:0.0];
	// Fade In timer also loads the welcome screen after its done fading in.
	//fadeInTimer = [[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fadeIn:) userInfo:nil repeats:YES] retain];
	// Load the theme store with all of the theme positions
	[self loadThemeStore];
	// Load window position from memory.
	[self restoreWindowPosition];
	// Monitor application quit
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
	// Begin monitoring iTunes
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(monitorTunes) userInfo:nil repeats:YES];
	// Allow for controls to disappear when mouse isn't in window.
	/*NSTrackingAreaOptions trackingOptions =
	NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved|NSTrackingActiveAlways;
	NSTrackingArea *myTrackingArea1 = [[NSTrackingArea alloc]
					   initWithRect: [imageView bounds] // in our case track the entire view
					   options: trackingOptions
					   owner: self
					   userInfo: nil];
	[imageView addTrackingArea: myTrackingArea1];*/
	[self loadTheme];
}

- (void)storeWindowPosition
{
	NSPoint windowOrigin = self.window.frame.origin;
	//[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect(windowFrame) forKey:@"musicaWindowFrame"];
	NSString *themeStoreFile = [[NSString alloc] initWithFormat:@"%@/TDStore.plist", [[NSFileManager defaultManager] applicationSupportDirectory]];
	if ([themeStore objectForKey:themeDictionary[@"BTThemeIdentifier"]]!=nil) {
		// update sub-dictionary, there has to be a less convoluted to manipulate this
		NSMutableDictionary *individualStore = [NSMutableDictionary dictionaryWithDictionary:[themeStore objectForKey:themeDictionary[@"BTThemeIdentifier"]]];
		[individualStore setObject:NSStringFromPoint(windowOrigin) forKey:@"BTWindowOrigin"];
		[themeStore setObject:individualStore forKey:themeDictionary[@"BTThemeIdentifier"]];
	}
	else {
		NSMutableDictionary *individualStore = [[NSMutableDictionary alloc] init];
		[individualStore setObject:NSStringFromPoint(windowOrigin) forKey:@"BTWindowOrigin"];
		[themeStore setObject:individualStore forKey:themeDictionary[@"BTThemeIdentifier"]];
	}
	[themeStore writeToFile:themeStoreFile atomically:YES];
}

-(void)restoreWindowPosition
{
	if ([themeStore objectForKey:themeDictionary[@"BTThemeIdentifier"]]!=nil) {
		// update sub-dictionary, there has to be a less convoluted to manipulate this
		NSMutableDictionary *individualStore = [NSMutableDictionary dictionaryWithDictionary:[themeStore objectForKey:themeDictionary[@"BTThemeIdentifier"]]];
		NSPoint windowOrigin = NSPointFromString([individualStore objectForKey:@"BTWindowOrigin"]);
		// only modify the origin
		NSRect windowFrame = NSMakeRect(windowOrigin.x, windowOrigin.y, self.window.frame.size.width, self.window.frame.size.height);
		[[self window] setFrame:windowFrame display:YES animate:NO];
	}
	else {
		[window center];
		NSLog(@"MusicaController No position to restore from.");
	}
}

- (void)fadeIn:(NSTimer *)theTimer
{
    if ([window alphaValue] < 1.0) {
        // If window is still partially opaque, reduce its opacity.
        [window setAlphaValue:[window alphaValue] + 0.2];
    } else {
        // Otherwise, if window is completely transparent, destroy the timer and close the window.
        [fadeInTimer invalidate];
        fadeInTimer = nil;
        
        //[window close];
        
        // Make the window fully opaque again for next time.
        [window setAlphaValue:1.0];
		// Load the welcome window if hasn't been unchecked.
		//[self openWelcomeWindow:nil];
    }
}

#pragma mark -
#pragma mark The Juicy Bits

-(void)monitorTunes {
    #ifndef __clang_analyzer__
    DescType playerState;
    RdioEPSS rdioPlayerState;
    SpotifyEPlS spotifyPlayerState;
    BOOL radiumPlayerState;
    NSInteger voxPlayerState;
    BOOL instacastPlayerState;
    if ([EyeTunes isRunning]) {
        EyeTunes *e = [EyeTunes sharedInstance];
        playerState = [e playerState];
    }
    if ([Instacast isRunning]) {
        instacastPlayerState = [Instacast playing];
    }
    if ([Radium isRunning]) {
        radiumPlayerState = [Radium playing];
    }
    if ([Rdio isRunning]) {
        rdioPlayerState = [Rdio playerState];
    }
    if ([Spotify isRunning]) {
        spotifyPlayerState = [Spotify playerState];
    }
    if ([Vox isRunning]) {
        voxPlayerState = [Vox playerState];
    }
    #endif
    
    // Analyzing the current running programs
    NSMutableArray *array=[[NSMutableArray alloc] init];
    if ([EyeTunes isRunning]) {
        [array addObject:@"iTunes"];
    }
    if ([Instacast isRunning]) {
        [array addObject:@"Instacast"];
    }
    if ([Radium isRunning]) {
        [array addObject:@"Radium"];
    }
    if ([Rdio isRunning]) {
        [array addObject:@"Rdio"];
    }
    if ([Spotify isRunning]) {
        [array addObject:@"Spotify"];
    }
    if ([Vox isRunning]) {
        [array addObject:@"Vox"];
    }
    // No players have opened or closed
    if ([audioPlayers isEqualToArray:array]) {
        // do nothing
    }
    else {
        // something has changed
        NSLog(@"MusicaController descr: %@, count: %lu", [array description], [array count]);
        if ([array count]>1) {
            // conditionally do the right thing with fading
            // show the window again
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaAlwaysShow"]) {
                [window orderFront:nil];
                fadeInTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fadeIn:) userInfo:nil repeats:YES];
            }
            NSLog(@"MusicaController more than program is open");
            //ask dialog
            resolvingConflict=YES;
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Please resolve conflict"];
            [alert setInformativeText:@"You have multiple sources open please choose one:"];
            int count = 0;
            for (NSString *application in array)
            {
                count += 1;
                if (count < 4)
                {
                    [alert addButtonWithTitle:application];
                }
            }
            NSModalResponse response = [alert runModal];
            int index = 0;
            
            switch (response) {
                case NSAlertFirstButtonReturn:
                    index = 0;
                    break;
                case NSAlertSecondButtonReturn:
                    index = 1;
                    break;
                case NSAlertThirdButtonReturn:
                    index = 2;
                    break;
                    
                default:
                    index = 0;
                    break;
            }

            NSString *chosenString = [array objectAtIndex:index];
            NSLog(@"MusicaController response:%ld string:%@", response, chosenString);
            // decode choice and choose it
            if ([chosenString isEqualToString:@"iTunes"]) {
                chosenPlayer=audioPlayeriTunes;
            }
            if ([chosenString isEqualToString:@"Instacast"]) {
                chosenPlayer=audioPlayerInstacast;
            }
            if ([chosenString isEqualToString:@"Radium"]) {
                chosenPlayer=audioPlayerRadium;
            }
            if ([chosenString isEqualToString:@"Rdio"]) {
                chosenPlayer=audioPlayerRdio;
            }
            if ([chosenString isEqualToString:@"Spotify"]) {
                chosenPlayer=audioPlayerSpotify;
            }
            if ([chosenString isEqualToString:@"Vox"]) {
                chosenPlayer=audioPlayerVox;
            }
        }
        // only one program is loaded
        else {
            resolvingConflict=NO;
            // no programs are loaded if user has decided to hide Musica now is the time
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaAlwaysShow"]) {
                if ([array count]==0) {
                    fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fadeOut:) userInfo:nil repeats:YES];
                }
                else {
                    // show the window again
                    [window orderFront:nil];
                    fadeInTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fadeIn:) userInfo:nil repeats:YES];
                }
            }
        }
    }
    // set up for previus referencing
    audioPlayers = array;
    
    // Preset conditionals to simplify the way the code looks and make it easier to read
    BOOL iTunesUsable = ([EyeTunes isRunning] && chosenPlayer==audioPlayeriTunes) || ([EyeTunes isRunning] && resolvingConflict==NO);
    BOOL instacastUsable = ([Instacast isRunning] && chosenPlayer==audioPlayerInstacast) || ([Instacast isRunning] && resolvingConflict==NO);
    BOOL rdioUsable = ([Rdio isRunning] && chosenPlayer==audioPlayerRdio) || ([Rdio isRunning] && resolvingConflict==NO);
    BOOL radiumUsable = ([Radium isRunning] && chosenPlayer==audioPlayerRadium) || ([Radium isRunning] && resolvingConflict==NO);
    BOOL spotifyUsable = ([Spotify isRunning] && chosenPlayer==audioPlayerSpotify) || ([Spotify isRunning] && resolvingConflict==NO);
    BOOL voxUsable = ([Vox isRunning] && chosenPlayer==audioPlayerVox) || ([Vox isRunning] && resolvingConflict==NO);
    
    // clang hates this whole thing... go figure
    #ifndef __clang_analyzer__
    // Change the playing button to the appropriate state
    // Detect is iTunes is paused and set button image
    if ((iTunesUsable==TRUE && playerState == kETPlayerStatePaused) || (instacastUsable==TRUE && instacastPlayerState == FALSE) || (radiumUsable==TRUE && radiumPlayerState==FALSE) || (rdioUsable==TRUE && rdioPlayerState == RdioEPSSPaused) || (spotifyUsable==TRUE && spotifyPlayerState == SpotifyEPlSPaused) || (voxUsable==TRUE && voxPlayerState == 0)) {
		// update theme playState variable
		if (![player.playState isEqual:@2]) {
			player.playState=@2;
			[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@(%@)",themeDictionary[@"BTPlayStateFunction"], player.playState]];
		}
    }
    if ((iTunesUsable==TRUE && playerState == kETPlayerStatePlaying) || (instacastUsable==TRUE && instacastPlayerState == TRUE) || (radiumUsable==TRUE && radiumPlayerState==TRUE) || (rdioUsable==TRUE && rdioPlayerState == RdioEPSSPlaying) || (spotifyUsable==TRUE && spotifyPlayerState == SpotifyEPlSPlaying) || (voxUsable==TRUE && voxPlayerState == 1)) {
		if (![player.playState isEqual:@1]) {
			player.playState=@1;
			[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@(%@)",themeDictionary[@"BTPlayStateFunction"], player.playState]];
		}
    }
    if ((iTunesUsable==TRUE && playerState == kETPlayerStateStopped) || (rdioUsable==TRUE && rdioPlayerState == RdioEPSSStopped) || (spotifyUsable==TRUE && spotifyPlayerState == SpotifyEPlSStopped)) {
		if (![player.playState isEqual:@0]) {
			player.playState=@0;
			[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@(%@)",themeDictionary[@"BTPlayStateFunction"], player.playState]];
		}
    }
    #endif
    
    
    //temp fix for waiting for app to load artwork
    //NSImage *artwork = [self updateArtwork];
    if (iTunesUsable) {
        EyeTunes *e = [EyeTunes sharedInstance];
        ETTrack *track = [e currentTrack];
		// register variables and callbacks with the theme
		player.playerPosition = [NSNumber numberWithInt:[e playerPosition]];
		[player setPlayCallback:^(){
			[e play];
		}];
		[player setPlayPauseCallback:^(){
			[e playPause];
		}];
		[player setPauseCallback:^(){
			[e play];
		}];
		[player setPreviousTrackCallback:^(){
			[e previousTrack];
		}];
		[player setNextTrackCallback:^(){
			[e nextTrack];
		}];
		//[track rating];
        if ([track name]==NULL) {
            NSLog(@"MusicaController No music is playing");
            //[self updateArtwork];
            // Reset these values because nothing is playing
            previousAlbum = nil;
            previousTrack = nil;
            NSLog(@"MusicaController Did we get called after animation has started");
        }
        if (![[track album] isEqualToString:previousAlbum] && [track album] != NULL) {
            NSLog(@"MusicaController Did we get called after animation has started");
            previousAlbum = [track album];
			[self trackChanged:track];
			[self updateArtwork];
        }
        if (![[track name] isEqualToString:previousTrack] && [track name] != NULL) {
            NSLog(@"MusicaController Track changed to: %@", [track name]);
            previousTrack = [track name];
			[self trackChanged:track];
			//NSImage *artwork = [self updateArtwork];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableNotifications"]) {
                NSUserNotification *notification = [[NSUserNotification alloc] init];
                [notification setTitle:[track name]];
				[notification setSubtitle:[track artist]];
				if ([notification respondsToSelector:@selector(setContentImage:)]) {
					[notification setContentImage:previousTrackArtwork];
				}
				[notification setInformativeText:[track album]];
                NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
                [center scheduleNotification:notification];
            }
        }
    }
    if (instacastUsable) {
        // register variables and callbacks with the theme
        __weak typeof(Instacast) weakInstacast = Instacast;
        player.playerPosition = [NSNumber numberWithDouble:[Instacast playerTime]];
        [player setPlayerPositionCallback:^(double position){
            [weakInstacast setPlayerTime:position];
        }];
        [player setPlayCallback:^(){
            [weakInstacast play];
        }];
        [player setPlayPauseCallback:^(){
            [weakInstacast playpause];
        }];
        [player setPauseCallback:^(){
            [weakInstacast pause];
        }];
        // Not applicable. Stations are streams not tracks.
        [player setPreviousTrackCallback:^(){
            [weakInstacast skipBackward];
        }];
        [player setNextTrackCallback:^(){
            [weakInstacast skipForward];
        }];
        if ([[Instacast currentEpisode] title]==NULL) {
            NSLog(@"MusicaController No music is playing");
            //[self updateArtwork];
            // Reset these values because nothing is playing
            previousAlbum = nil;
            previousTrack = nil;
            NSLog(@"MusicaController Did we get called after animation has started");
        }
        if (![[[[Instacast currentEpisode] podcast] title] isEqualToString:previousAlbum] && [[[Instacast currentEpisode] podcast] title] != NULL) {
            NSLog(@"MusicaController Did we get called after animation has started");
            previousAlbum = [[[Instacast currentEpisode] podcast] title];
            [self updateArtwork];
        }
        if (![[[Instacast currentEpisode] title] isEqualToString:previousTrack] && [[Instacast currentEpisode] title] != NULL) {
            NSLog(@"MusicaController Track changed to: %@", [[Instacast currentEpisode] title]);
            previousTrack = [[Instacast currentEpisode] title];
            [self trackChanged:[Instacast currentEpisode]];
            [self updateArtwork];
        }
    }
    if (radiumUsable) {
        //RadiumRplayer *track = [Radium player];
        // register variables and callbacks with the theme
        __weak typeof(Radium) weakRadium = Radium;
        [player setPlayCallback:^(){
            [weakRadium play];
        }];
        [player setPlayPauseCallback:^(){
            [weakRadium playpause];
        }];
        [player setPauseCallback:^(){
            [weakRadium pause];
        }];
        // Not applicable. Stations are streams not tracks.
        [player setPreviousTrackCallback:^(){
        }];
        [player setNextTrackCallback:^(){
        }];
        if ([Radium trackName]==NULL) {
            NSLog(@"MusicaController No music is playing");
            //[self updateArtwork];
            // Reset these values because nothing is playing
            previousAlbum = nil;
            previousTrack = nil;
            NSLog(@"MusicaController Did we get called after animation has started");
        }
        if (![[Radium trackName] isEqualToString:previousTrack] && [Radium trackName] != NULL) {
            if ([Radium trackArtwork]!=nil) {
                [self updateArtwork];
            }
            NSLog(@"MusicaController Track changed to: %@", [Radium trackName]);
            previousTrack = [Radium trackName];
            [self trackChanged:Radium];
            [self updateArtwork];
        }
    }
    if (rdioUsable) {
        RdioTrack *track = [Rdio currentTrack];
		// register variables and callbacks with the theme
		player.playerPosition = [NSNumber numberWithDouble:[Rdio playerPosition]];
		__weak typeof(Rdio) weakRdio = Rdio;
        [player setPlayerPositionCallback:^(double position){
            [weakRdio setPlayerPosition:(NSInteger)position];
        }];
		[player setPlayCallback:^(){
			[weakRdio playSource:@""];
		}];
		[player setPlayPauseCallback:^(){
			[weakRdio playpause];
		}];
		[player setPauseCallback:^(){
			[weakRdio pause];
		}];
		[player setPreviousTrackCallback:^(){
			[weakRdio previousTrack];
		}];
		[player setNextTrackCallback:^(){
			[weakRdio nextTrack];
		}];
        if ([track name]==NULL) {
            NSLog(@"MusicaController No music is playing");
            //[self updateArtwork];
            // Reset these values because nothing is playing
            previousAlbum = nil;
            previousTrack = nil;
            NSLog(@"MusicaController Did we get called after animation has started");
        }
        if (![[track album] isEqualToString:previousAlbum] && [track album] != NULL) {
            NSLog(@"MusicaController Did we get called after animation has started");
            previousAlbum = [track album];
			[self updateArtwork];
        }
        if (![[track name] isEqualToString:previousTrack] && [track name] != NULL) {
            NSLog(@"MusicaController Track changed to: %@", [track name]);
            previousTrack = [track name];
			[self trackChanged:track];
			//[self updateArtwork];
        }
    }
    if (spotifyUsable) {
        SpotifyTrack *track = [Spotify currentTrack];
		// register variables and callbacks with the theme
		player.playerPosition = [NSNumber numberWithDouble:[Spotify playerPosition]];
		__weak typeof(Spotify) weakSpotify = Spotify;
        [player setPlayerPositionCallback:^(double position){
            [weakSpotify setPlayerPosition:position];
        }];
		[player setPlayCallback:^(){
			[weakSpotify play];
		}];
		[player setPlayPauseCallback:^(){
			[weakSpotify playpause];
		}];
		[player setPauseCallback:^(){
			[weakSpotify pause];
		}];
		[player setPreviousTrackCallback:^(){
			[weakSpotify previousTrack];
		}];
		[player setNextTrackCallback:^(){
			[weakSpotify nextTrack];
		}];
        if ([track name]==NULL) {
            NSLog(@"MusicaController No music is playing");
            //[self updateArtwork];
            // Reset these values because nothing is playing
            previousAlbum = nil;
            previousTrack = nil;
            NSLog(@"MusicaController Did we get called after animation has started");
        }
        if (![[track album] isEqualToString:previousAlbum] && [track album] != NULL) {
            NSLog(@"MusicaController Did we get called after animation has started");
            previousAlbum = [track album];
			[self updateArtwork];
        }
        if (![[track name] isEqualToString:previousTrack] && [track name] != NULL) {
            NSLog(@"MusicaController Track changed to: %@", [track name]);
            previousTrack = [track name];
			[self trackChanged:track];
			//NSImage *artwork = [self updateArtwork];
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableNotifications"]) {
                NSUserNotification *notification = [[NSUserNotification alloc] init];
                [notification setTitle:[track name]];
				[notification setSubtitle:[track artist]];
				if ([notification respondsToSelector:@selector(setContentImage:)]) {
					[notification setContentImage:previousTrackArtwork];
				}
				[notification setInformativeText:[track album]];
                NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
                [center scheduleNotification:notification];
            }
        }
    }
    if (voxUsable) {
        // register variables and callbacks with the theme
        __weak typeof(Vox) weakVox = Vox;
        player.playerPosition = [NSNumber numberWithDouble:[Vox currentTime]];
        [player setPlayerPositionCallback:^(double position){
            [weakVox setCurrentTime:position];
        }];
        [player setPlayCallback:^(){
            [weakVox play];
        }];
        [player setPlayPauseCallback:^(){
            [weakVox playpause];
        }];
        [player setPauseCallback:^(){
            [weakVox pause];
        }];
        // Not applicable. Stations are streams not tracks.
        [player setPreviousTrackCallback:^(){
            [weakVox previous];
        }];
        [player setNextTrackCallback:^(){
            [weakVox next];
        }];
        if ([Vox track]==NULL) {
            NSLog(@"MusicaController No music is playing");
            //[self updateArtwork];
            // Reset these values because nothing is playing
            previousAlbum = nil;
            previousTrack = nil;
            NSLog(@"MusicaController Did we get called after animation has started");
        }
        if (![[Vox album] isEqualToString:previousAlbum] && [Vox album] != NULL) {
            NSLog(@"MusicaController Did we get called after animation has started");
            previousAlbum = [Vox album];
            [self updateArtwork];
        }
        if (![[Vox track] isEqualToString:previousTrack] && [Vox track] != NULL) {
            NSLog(@"MusicaController Track changed to: %@", [Vox track]);
            previousTrack = [Vox track];
            [self trackChanged:Vox];
            [self updateArtwork];
        }
    }
	// update theme status
	[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@()",themeDictionary[@"BTStatusFunction"]]];
}

- (BOOL)image:(NSImage *)image1 isEqualTo:(NSImage *)image2
{
    NSData *data1 = [image1 TIFFRepresentation];
    NSData *data2 = [image2 TIFFRepresentation];
	
    return [data1 isEqualToData:data2];
}

-(NSImage*)updateArtwork {
    if (([EyeTunes isRunning] && chosenPlayer==audioPlayeriTunes) || ([EyeTunes isRunning] && resolvingConflict==NO)) {
		EyeTunes *e = [EyeTunes sharedInstance];
		ETTrack *currentTrack = [e currentTrack];
		NSArray *artworks = [currentTrack artwork];
		
		if ([artworks count] > 0) 
		{
			NSLog(@"MusicaController Artwork found");
			
			if ([self image:previousTrackArtwork isEqualTo:[artworks objectAtIndex:0]])
			{
				return previousTrackArtwork;
			}
			NSImage *albumImage = [artworks objectAtIndex:0];
			previousTrackArtwork = albumImage;
			albumData = [albumImage TIFFRepresentation];
			// check for specified artwork dimensions
			if (themeDictionary[@"BTArtworkHeight"]!=nil && themeDictionary[@"BTArtworkWidth"]!=nil) {
				albumData = [albumImage dataOfResizeForWidth:[themeDictionary[@"BTArtworkWidth"] floatValue] andHeight:[themeDictionary[@"BTArtworkHeight"] floatValue]];
			}
			[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@('data:image/tiff;base64,%@')", themeDictionary[@"BTArtworkFunction"], [albumData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]];
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
				// Overlay icon over album art
				/*NSImage *resultImage = [albumImage copy];
                 [resultImage lockFocus];
                 
                 NSImage* defaultImage = [NSImage imageNamed: @"Overlay"];
                 [defaultImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
                 // Or any of the other about 6 options; see Apple's guide to pick.
                 
                 [resultImage unlockFocus];
                 [NSApp setApplicationIconImage: resultImage];*/
				[NSApp setApplicationIconImage: albumImage];
			}
			return albumImage;
		}
		else {
			NSLog(@"MusicaController No artwork found");
			if ([self image:previousTrackArtwork isEqualTo:[NSImage imageNamed:@"MissingArtwork.png"]])
			{
				return previousTrackArtwork;
			}
			NSImage *albumImage = [NSImage imageNamed:@"MissingArtwork.png"];
			previousTrackArtwork = albumImage;
			albumData = [albumImage TIFFRepresentation];
			// check for specified artwork dimensions
			if (themeDictionary[@"BTArtworkHeight"]!=nil && themeDictionary[@"BTArtworkWidth"]!=nil) {
				albumData = [albumImage dataOfResizeForWidth:[themeDictionary[@"BTArtworkWidth"] floatValue] andHeight:[themeDictionary[@"BTArtworkHeight"] floatValue]];
			}
			[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@('data:image/tiff;base64,%@')", themeDictionary[@"BTArtworkFunction"], [albumData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]];
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
				//[NSApp setApplicationIconImage: albumImage];
				[NSApp setApplicationIconImage:[NSImage imageNamed:@"NSImageNameApplicationIcon"]];
			}
			return albumImage;
		}
	}
    if (([Instacast isRunning] && chosenPlayer==audioPlayerInstacast) || ([Instacast isRunning] && resolvingConflict==NO)) {
//        albumData = [NSData new];
        InstacastEpisode *episode= [Instacast currentEpisode];
        //NSLog(@"image:%@", episode);
        NSImage *albumImage = nil;
        //NSImage *albumImage = [[NSImage alloc] initWithData:[episode artwork]];
//        NSImage *albumImage = [[NSImage alloc] initWithData:albumData];
        
        if ([self image:previousTrackArtwork isEqualTo:albumImage])
        {
            return previousTrackArtwork;
        }
        previousTrackArtwork = albumImage;
        albumData = [albumImage TIFFRepresentation];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
            [NSApp setApplicationIconImage: albumImage];
        }
        if (albumImage==nil) {
            NSLog(@"MusicaController No artwork found");
            if ([self image:previousTrackArtwork isEqualTo:[NSImage imageNamed:@"MissingArtwork.png"]])
            {
                return previousTrackArtwork;
            }
            NSImage *albumImage = [NSImage imageNamed:@"MissingArtwork.png"];
            previousTrackArtwork = albumImage;
            albumData = [albumImage TIFFRepresentation];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
                //[NSApp setApplicationIconImage: albumImage];
                [NSApp setApplicationIconImage:[NSImage imageNamed:@"NSImageNameApplicationIcon"]];
            }
        }
        // check for specified artwork dimensions
        if (themeDictionary[@"BTArtworkHeight"]!=nil && themeDictionary[@"BTArtworkWidth"]!=nil) {
            albumData = [albumImage dataOfResizeForWidth:[themeDictionary[@"BTArtworkWidth"] floatValue] andHeight:[themeDictionary[@"BTArtworkHeight"] floatValue]];
        }
        [webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@('data:image/tiff;base64,%@')", themeDictionary[@"BTArtworkFunction"], [albumData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]];
        return albumImage;
    }
    if (([Radium isRunning] && chosenPlayer==audioPlayerRadium) || ([Radium isRunning] && resolvingConflict==NO)) {
        //NSLog(@"Radium awesomeness");
        if ([self image:previousTrackArtwork isEqualTo:[Radium trackArtwork]])
        {
            return previousTrackArtwork;
        }
        NSImage *albumImage = [Radium trackArtwork];
        previousTrackArtwork = albumImage;
        albumData = [albumImage TIFFRepresentation];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
            [NSApp setApplicationIconImage: albumImage];
        }
        if (albumImage==nil) {
            NSLog(@"MusicaController No artwork found");
            if ([self image:previousTrackArtwork isEqualTo:[NSImage imageNamed:@"MissingArtwork.png"]])
            {
                return previousTrackArtwork;
            }
            NSImage *albumImage = [NSImage imageNamed:@"MissingArtwork.png"];
            previousTrackArtwork = albumImage;
            albumData = [albumImage TIFFRepresentation];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
                //[NSApp setApplicationIconImage: albumImage];
                [NSApp setApplicationIconImage:[NSImage imageNamed:@"NSImageNameApplicationIcon"]];
            }
        }
        // check for specified artwork dimensions
        if (themeDictionary[@"BTArtworkHeight"]!=nil && themeDictionary[@"BTArtworkWidth"]!=nil) {
            albumData = [albumImage dataOfResizeForWidth:[themeDictionary[@"BTArtworkWidth"] floatValue] andHeight:[themeDictionary[@"BTArtworkHeight"] floatValue]];
        }
        [webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@('data:image/tiff;base64,%@')", themeDictionary[@"BTArtworkFunction"], [albumData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]];
        return albumImage;
    }
    if (([Rdio isRunning] && chosenPlayer==audioPlayerRdio) || ([Rdio isRunning] && resolvingConflict==NO)) {
        // BAD Rdio! sdf ouput reports NSData type but it's actually NSImage
        NSImage *albumImage = [[Rdio currentTrack] artwork];
		if ([self image:previousTrackArtwork isEqualTo:albumImage])
		{
			return previousTrackArtwork;
		}
		previousTrackArtwork = albumImage;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
            [NSApp setApplicationIconImage: albumImage];
        }
        if (albumImage==nil) {
            NSLog(@"MusicaController No artwork found");
            // ignore the warning here. it makes no sense the type returned is actually NSImage
            if ([self image:previousTrackArtwork isEqualTo:[NSImage imageNamed:@"MissingArtwork.png"]])
			{
				return previousTrackArtwork;
			}
			NSImage *albumImage = [NSImage imageNamed:@"MissingArtwork.png"];
			previousTrackArtwork = albumImage;
            albumData = [albumImage TIFFRepresentation];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
                //[NSApp setApplicationIconImage: albumImage];
                [NSApp setApplicationIconImage:[NSImage imageNamed:@"NSImageNameApplicationIcon"]];
            }
        }
		// check for specified artwork dimensions
		if (themeDictionary[@"BTArtworkHeight"]!=nil && themeDictionary[@"BTArtworkWidth"]!=nil) {
			albumData = [albumImage dataOfResizeForWidth:[themeDictionary[@"BTArtworkWidth"] floatValue] andHeight:[themeDictionary[@"BTArtworkHeight"] floatValue]];
		}
		[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@('data:image/tiff;base64,%@')", themeDictionary[@"BTArtworkFunction"], [albumData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]];
		return albumImage;
    }
    if (([Spotify isRunning] && chosenPlayer==audioPlayerSpotify) || ([Spotify isRunning] && resolvingConflict==NO)) {
		if ([self image:previousTrackArtwork isEqualTo:[[Spotify currentTrack] artwork]])
		{
			return previousTrackArtwork;
		}
        NSImage *albumImage = [[Spotify currentTrack] artwork];
		previousTrackArtwork = albumImage;
        albumData = [albumImage TIFFRepresentation];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
            [NSApp setApplicationIconImage: albumImage];
        }
        if (albumImage==nil) {
            NSLog(@"MusicaController No artwork found");
            if ([self image:previousTrackArtwork isEqualTo:[NSImage imageNamed:@"MissingArtwork.png"]])
			{
				return previousTrackArtwork;
			}
			NSImage *albumImage = [NSImage imageNamed:@"MissingArtwork.png"];
			previousTrackArtwork = albumImage;
            albumData = [albumImage TIFFRepresentation];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
                //[NSApp setApplicationIconImage: albumImage];
                [NSApp setApplicationIconImage:[NSImage imageNamed:@"NSImageNameApplicationIcon"]];
            }
        }
		// check for specified artwork dimensions
		if (themeDictionary[@"BTArtworkHeight"]!=nil && themeDictionary[@"BTArtworkWidth"]!=nil) {
			albumData = [albumImage dataOfResizeForWidth:[themeDictionary[@"BTArtworkWidth"] floatValue] andHeight:[themeDictionary[@"BTArtworkHeight"] floatValue]];
		}
		[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@('data:image/tiff;base64,%@')", themeDictionary[@"BTArtworkFunction"], [albumData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]];
		return albumImage;
    }
    if (([Vox isRunning] && chosenPlayer==audioPlayerVox) || ([Vox isRunning] && resolvingConflict==NO)) {
        if ([self image:previousTrackArtwork isEqualTo:[Vox artworkImage]])
        {
            return previousTrackArtwork;
        }
        NSImage *albumImage = [Vox artworkImage];
        previousTrackArtwork = albumImage;
        albumData = [albumImage TIFFRepresentation];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
            [NSApp setApplicationIconImage: albumImage];
        }
        if (albumImage==nil) {
            NSLog(@"MusicaController No artwork found");
            if ([self image:previousTrackArtwork isEqualTo:[NSImage imageNamed:@"MissingArtwork.png"]])
            {
                return previousTrackArtwork;
            }
            NSImage *albumImage = [NSImage imageNamed:@"MissingArtwork.png"];
            previousTrackArtwork = albumImage;
            albumData = [albumImage TIFFRepresentation];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"musicaEnableDockArt"]) {
                //[NSApp setApplicationIconImage: albumImage];
                [NSApp setApplicationIconImage:[NSImage imageNamed:@"NSImageNameApplicationIcon"]];
            }
        }
        // check for specified artwork dimensions
        if (themeDictionary[@"BTArtworkHeight"]!=nil && themeDictionary[@"BTArtworkWidth"]!=nil) {
            albumData = [albumImage dataOfResizeForWidth:[themeDictionary[@"BTArtworkWidth"] floatValue] andHeight:[themeDictionary[@"BTArtworkHeight"] floatValue]];
        }
        [webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@('data:image/tiff;base64,%@')", themeDictionary[@"BTArtworkFunction"], [albumData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]];
        return albumImage;
    }
	return nil;
}

#pragma mark -
#pragma mark Theming

- (void)loadTheme
{
	// save current theme position if we just switched themes
	if (themeDictionary!=nil) {
		[self storeWindowPosition];
	}
	NSURL *themeURL = [ThemeLoader appliedThemeURL];
    NSURL *plistURL = [themeURL URLByAppendingPathComponent:@"Info.plist"];
	themeDictionary = [NSDictionary dictionaryWithContentsOfURL:plistURL];
    NSURL *indexFile = [[ThemeLoader appliedThemeURL] URLByAppendingPathComponent:themeDictionary[@"BTMainFile"]];
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:indexFile]];
}

- (IBAction)loadThemeFromFile:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:YES];
	[panel setAllowsMultipleSelection:NO]; // yes if more than one dir is allowed
	
	NSInteger clicked = [panel runModal];
	
	if (clicked == NSFileHandlingPanelOKButton) {
		[ThemeLoader installTheme:[panel URL]];
		/*themeDictionary = [NSDictionary dictionaryWithContentsOfURL:[[panel URL] URLByAppendingPathComponent:@"Info.plist"]];
		NSURL *indexFile = [[panel URL] URLByAppendingPathComponent:themeDictionary[@"BTMainFile"]];
		[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:indexFile]];*/
	}
}

// load the theme positions, also can contain specific theme preferences, hence the name store
- (void)loadThemeStore
{
	NSString *themeStoreFile = [[NSString alloc] initWithFormat:@"%@/TDStore.plist", [[NSFileManager defaultManager] applicationSupportDirectory]];
	themeStore = [NSMutableDictionary dictionaryWithContentsOfFile:themeStoreFile];
	if (themeStore==nil) {
		themeStore = [[NSMutableDictionary alloc] init];
	}
}

- (void)trackChanged:(id)track
{
	WebScriptObject *scriptObject = [webView windowScriptObject];
	Track *theTrack = [[Track alloc] init];
	if ([track isMemberOfClass:[ETTrack class]]) {
		[theTrack setTitle:((ETTrack*)track).name];
		[theTrack setAlbum:((ETTrack*)track).album];
		[theTrack setArtist:((ETTrack*)track).albumArtist];
		[theTrack setGenre:((ETTrack*)track).genre];
		[theTrack setLength:[NSNumber numberWithInt:((ETTrack*)track).duration]];
		[player setRatingNumber:[NSNumber numberWithInt:((ETTrack*)track).rating]];
	}
    if ([[track className] isEqualToString:@"InstacastEpisode"]) {
        [theTrack setTitle:((InstacastEpisode*)track).title];
        [theTrack setAlbum:((InstacastEpisode*)track).podcast.title];
        [theTrack setArtist:((InstacastEpisode*)track).podcast.author];
        [theTrack setGenre:@""];
        [theTrack setLength:[NSNumber numberWithDouble:[Instacast playableDuration]]];
        [player setRatingNumber:@0];
    }
	if ([[track className] isEqualToString:@"RadiumApplication"])
	{
		[theTrack setTitle:[Radium trackName]];
		[theTrack setAlbum:@""];
		[theTrack setArtist:[Radium stationName]];
		[theTrack setGenre:@""];
		[theTrack setLength:@0];
		[player setRatingNumber:@0];
	}
	if ([[track className] isEqualToString:@"RdioTrack"])
	{
		[theTrack setTitle:((RdioTrack*)track).name];
		[theTrack setAlbum:((RdioTrack*)track).album];
		[theTrack setArtist:((RdioTrack*)track).artist];
		[theTrack setGenre:@""];
		[theTrack setLength:[NSNumber numberWithInt:((RdioTrack*)track).duration]];
		[player setRatingNumber:@0];
	}
    if ([[track className] isEqualToString:@"SpotifyTrack"])
    {
        [theTrack setTitle:((SpotifyTrack*)track).name];
        [theTrack setAlbum:((SpotifyTrack*)track).album];
        [theTrack setArtist:((SpotifyTrack*)track).artist];
        [theTrack setGenre:@""];
        [theTrack setLength:[NSNumber numberWithInt:((SpotifyTrack*)track).duration]];
        [player setRatingNumber:[NSNumber numberWithInteger:((SpotifyTrack*)track).popularity]];
    }
    if ([[track className] isEqualToString:@"VOXApplication"])
    {
        [theTrack setTitle:[Vox track]];
        [theTrack setAlbum:[Vox album]];
        [theTrack setArtist:[Vox artist]];
        [theTrack setGenre:@""];
        [theTrack setLength:[NSNumber numberWithDouble:[Vox totalTime]]];
        [player setRatingNumber:@0];
    }
	player.currentTrack = theTrack;
	[scriptObject setValue:theTrack forKey:@"theTrack"];
	NSString *trackScript = [[NSString alloc] initWithFormat:@"%@(window.theTrack);",themeDictionary[@"BTTrackFunction"]];
	[webView stringByEvaluatingJavaScriptFromString:trackScript];
	[scriptObject removeWebScriptKey:@"theTrack"];
	// redraw the screen.. keep artifcats from gathering
	[webView display];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	float width = [themeDictionary[@"BTWindowWidth"] doubleValue];
	float height = [themeDictionary[@"BTWindowHeight"] doubleValue];
	//NSRect frame = NSMakeRect(webView.frame.origin.x, webView.frame.origin.y, width, height);
	NSRect windowFrame = NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, width, height);
	[window setFrame:windowFrame display:YES];
	[self restoreWindowPosition];
	
	// register bridge values
	[[webView windowScriptObject] setValue:player forKey:@"Player"];
	[[webView windowScriptObject] setValue:bowtie forKey:@"Bowtie"];
	[webView stringByEvaluatingJavaScriptFromString:@"var Player = window.Player; var iTunes = window.Player;"];
	[webView stringByEvaluatingJavaScriptFromString:@"var Bowtie = window.Bowtie;"];
	
	// setup bridge for dragging the window
	NSString *mouseBridgeScript = @"document.addEventListener('mousedown', function(e) { Bowtie.mouseDownWithPoint(e.screenX, e.screenY); }); document.addEventListener('mousemove', function(e) { Bowtie.mouseMovedWithPoint(e.screenX, e.screenY); }); document.addEventListener('mouseup', function(e) { Bowtie.mouseUp(); });";
	[webView stringByEvaluatingJavaScriptFromString:mouseBridgeScript];
	
	// reset the previous track and artwork so that it force a reload of the info into the theme
	previousTrack = nil;
	previousTrackArtwork = nil;
	[self updateArtwork];
	[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@(%@)",themeDictionary[@"BTPlayStateFunction"], player.playState]];
	[webView stringByEvaluatingJavaScriptFromString:[[NSString alloc] initWithFormat:@"%@();",themeDictionary[@"BTReadyFunction"]]];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element
    defaultMenuItems:(NSArray *)defaultMenuItems
{
    // disable right-click context menu
    return nil;
}

- (BOOL)webView:(WebView *)webView shouldChangeSelectedDOMRange:(DOMRange *)currentRange
	 toDOMRange:(DOMRange *)proposedRange
	   affinity:(NSSelectionAffinity)selectionAffinity
 stillSelecting:(BOOL)flag
{
    // disable text selection
    return NO;
}

- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	return WebDragDestinationActionNone;
}

- (NSUInteger)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point
{
	return WebDragSourceActionNone;
}

#pragma mark - Last.fm Stuff

- (void)loginLFM
{
	lfmWebService = [[LFWebService alloc] init];
	[lfmWebService setAPIKey:@"eaefece415e6baf1679168618691879d"];
	[lfmWebService setSharedSecret:@"0b7caa8184e2230a85a203e4fed75b24"];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)openPreferences:(id)sender {
	// lazy load the PreferencesController
	if (!self.preferencesController) {
		PreferencesController *pC = [[PreferencesController alloc] init];
		self.preferencesController =  pC;
	}
	
	[self.preferencesController showWindow:self];
}

#pragma mark -

// Installing a theme
- (BOOL) application:(NSApplication *)sender openFile:(NSString *)source {
    [ThemeLoader installTheme:[NSURL URLWithString:source]];
    
	return YES;
}

// Play/pause on Dock Icon Click if we are in minimal mode
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)flag
{
    /*NSBeep();
    NSLog(@"Hi");*/
    // play/pause music here
    //[self playPause:nil];
    
    return YES;
}

@end
