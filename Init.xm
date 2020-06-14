#import "MusicPreferences.h"

extern void initVolumeControl();
extern void initMusicWidgetHelper();
extern void initMusicWidget();
extern void initMusicApp();
extern void initMusicAppHelper();
extern void initExtraButtons();
extern void initMediaNotification();
extern void initCompactMediaPlayer();

static MusicPreferences *preferences;

%ctor
{
    @autoreleasepool
	{
        preferences = [MusicPreferences sharedInstance];
		if([preferences enabled])
        {
            NSString *processName = [NSProcessInfo processInfo].processName;
            bool isSpringboard = [@"SpringBoard" isEqualToString: processName];
            bool isMusicApp = [@"Music" isEqualToString: processName];

            if(isSpringboard) 
            {
                if([preferences showNotification])
                    initMediaNotification();
                if([preferences addExtraButtonsToLockScreen] || [preferences addExtraButtonsToControlCenter])
                    initExtraButtons();
                initVolumeControl();
                initMusicWidgetHelper();
                if([preferences lockScreenMusicWidgetStyle] == 1)
                    initCompactMediaPlayer();
                initMusicWidget();
            }
            if(isMusicApp)
            {
                initMusicAppHelper();
                initMusicApp();
            }
        }
    }
}