#import "MusicPreferences.h"
#import "MusicApp.h"
#import "Colorizer.h"
#include <sys/sysctl.h>

#define IS_iPAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

NSArray *const NOTCHED_IPHONES = @[@"iPhone10,3", @"iPhone10,6", @"iPhone11,2", @"iPhone11,6", @"iPhone11,8", @"iPhone12,1", @"iPhone12,3", @"iPhone12,5"];
BOOL isNotchediPhone;
CGFloat screenWidth;

static MusicPreferences *preferences;
static Colorizer *colorizer;

void roundCorners(UIView* view, double topCornerRadius, double bottomCornerRadius)
{
	CGRect bounds = [view bounds];
	if(!IS_iPAD) bounds.size.height -= 55;
	
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    [maskLayer setFrame: bounds];
    [maskLayer setPath: ((UIBezierPath*)[UIBezierPath roundedRectBezierPath: bounds withTopCornerRadius: topCornerRadius withBottomCornerRadius: bottomCornerRadius]).CGPath];
    [[view layer] setMask: maskLayer];

    CAShapeLayer *frameLayer = [CAShapeLayer layer];
    [frameLayer setFrame: bounds];
    [frameLayer setLineWidth: [preferences musicAppBorderWidth]];
    [frameLayer setPath: [maskLayer path]];
    [frameLayer setFillColor: nil];

    [[view layer] addSublayer: frameLayer];
}

static void produceLightVibration()
{
	UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle: UIImpactFeedbackStyleLight];
	[gen prepare];
	[gen impactOccurred];
}

static NSString* getDeviceModel()
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *model = (char*)malloc(size);
    sysctlbyname("hw.machine", model, &size, NULL, 0);
    NSString *deviceModel = [NSString stringWithCString: model encoding: NSUTF8StringEncoding];
    free(model);
    return deviceModel;
}

// -------------------------------------- NowPlayingViewController  ------------------------------------------------

%hook _MPCAVController

- (void)_itemWillChange: (id)arg
{
	%orig;

	id newItem = [arg objectForKeyedSubscript: @"new"];
	if(newItem && [newItem isKindOfClass: %c(MPCModelGenericAVItem)])
	{
		MPMediaItem *mediaItem = [newItem mediaItem];
		UIImage *image = [[mediaItem artwork] imageWithSize: CGSizeMake(128, 128)];

		[colorizer generateColorsForArtwork: image withTitle: [mediaItem title]];
	}
}

%end

// -------------------------------------- NowPlayingViewController  ------------------------------------------------

%hook NowPlayingViewController

- (id)init
{
	self = %orig;
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(colorize) name: @"MusicArtworkChanged" object: nil];
	return self;
}

- (void)viewDidLayoutSubviews
{
	%orig;
	[self colorize];
}

%new
- (void)colorize
{
	if([colorizer backgroundColor])
	{
		UIView *backgroundView = MSHookIvar<UIView*>(self, "backgroundView");
		UIView *contentView = [backgroundView contentView];
		UIView *newView = [contentView viewWithTag: 0xffeedd];
		if(!newView)
		{
			newView = [[UIView alloc] initWithFrame: [contentView bounds]];
			[newView setAutoresizingMask: UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
			[newView setTag: 0xffeedd];
			[newView setOpaque: NO];
			[newView setClipsToBounds: YES];
			
			if([preferences addMusicAppBorder])
			{
				if(isNotchediPhone)
					roundCorners(newView, 10, 40);
				else
				{
					[[newView layer] setCornerRadius: 10];
					[[newView layer] setBorderWidth: [preferences musicAppBorderWidth]];
					[[newView layer] setMaskedCorners: kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner];
				}
			}

			[contentView addSubview: newView];
		}
		
		[contentView setBackgroundColor: [UIColor clearColor]];

		[UIView animateWithDuration: [colorizer backgroundColorChangeDuration] animations:
		^{
			[newView setBackgroundColor: [colorizer backgroundColor]];
			if([preferences addMusicAppBorder])
			{
				if(isNotchediPhone)
					[[[newView layer] sublayers][0] setStrokeColor: [colorizer primaryColor].CGColor];
				else
					[[newView layer] setBorderColor: [colorizer primaryColor].CGColor];
			}
		}
		completion: nil];

		MusicNowPlayingControlsViewController *controlsViewController = MSHookIvar<MusicNowPlayingControlsViewController*>(self, "controlsViewController");
		[controlsViewController colorize];
	}
}

%end

// -------------------------------------- MusicNowPlayingControlsViewController  ------------------------------------------------

%hook MusicNowPlayingControlsViewController

%new
- (void)colorize
{
	UIView *bottomContainerView = MSHookIvar<UIView*>(self, "bottomContainerView");
	[bottomContainerView setCustomBackgroundColor: [UIColor clearColor]];
	[bottomContainerView setBackgroundColor: [UIColor clearColor]];

	UIView *grabberView = MSHookIvar<UIView*>(self, "grabberView");
	[grabberView setCustomBackgroundColor: [colorizer primaryColor]];
	[grabberView setBackgroundColor: [colorizer primaryColor]];

	[[self titleLabel] setCustomTextColor: [colorizer primaryColor]];
	[[self titleLabel] setTextColor: [colorizer primaryColor]];

	[[self subtitleButton] setCustomTitleColor: [colorizer secondaryColor]];
	[[self subtitleButton] setTitleColor: [colorizer secondaryColor] forState: UIControlStateNormal];
	
	[[self accessibilityLyricsButton] setSpecialButton: @1];
	[[self accessibilityLyricsButton] updateButtonColor];

	[[self routeButton] setCustomTintColor: [colorizer secondaryColor]];
	[[self routeButton] setTintColor: [colorizer secondaryColor]];

	[[self routeLabel] setCustomTextColor: [colorizer secondaryColor]];
	[[self routeLabel] setTextColor: [colorizer secondaryColor]];

	[[self accessibilityQueueButton] setSpecialButton: @2];
	[[self accessibilityQueueButton] updateButtonColor];

	UIView *queueModeBadgeView = MSHookIvar<UIView*>(self, "queueModeBadgeView");
	[queueModeBadgeView setCustomTintColor: [colorizer backgroundColor]];
	[queueModeBadgeView setTintColor: [colorizer backgroundColor]];
	[queueModeBadgeView setCustomBackgroundColor: [colorizer primaryColor]];
	[queueModeBadgeView setBackgroundColor: [colorizer primaryColor]];

	[[self leftButton] colorize];
	[[self playPauseStopButton] colorize];
	[[self rightButton] colorize];

	[[[self contextButton] superview] setAlpha: 1.0];
	[[self contextButton] colorize];

	[MSHookIvar<NowPlayingContentView*>(self, "artworkView") colorize];
	[MSHookIvar<PlayerTimeControl*>(self, "timeControl") colorize];
	[MSHookIvar<MPVolumeSlider*>(self, "volumeSlider") colorize];
}

%end

// -------------------------------------- NowPlayingContentView  ------------------------------------------------

%hook NowPlayingContentView

%property(nonatomic, retain) UIImageView *artworkImageView;

- (void)layoutSubviews
{
	%orig;

	if(![self artworkImageView] || [[self artworkImageView] observationInfo] == nil)
	{
		for(UIView *subview in [self subviews])
		{
			if([subview isKindOfClass: %c(_TtC16MusicApplication25ArtworkComponentImageView)])
			{
				[self setArtworkImageView: (UIImageView*)subview];
				break;
			}
		}
		if([self artworkImageView])
			[[self artworkImageView] addObserver: self forKeyPath: @"image" options: NSKeyValueObservingOptionNew context: nil];
	}

	[[self layer] setShadowOpacity: 0];
}

%new
- (void)observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object change: (NSDictionary<NSKeyValueChangeKey, id>*)change context: (void*)context
{
	if([[self _viewControllerForAncestor] isKindOfClass: %c(MusicNowPlayingControlsViewController)] || [[self _viewControllerForAncestor] isKindOfClass: %c(_TtC16MusicApplication24MiniPlayerViewController)])
	{
		if([[[self artworkImageView] image] isKindOfClass: %c(UIImage)])
		{
			UIImage *image = [[self artworkImageView] image];
			if(image && [image size].width > 0)
			{
				NSString *title;
				if([[self _viewControllerForAncestor] isKindOfClass: %c(MusicNowPlayingControlsViewController)])
					title = [[(MusicNowPlayingControlsViewController*)[self _viewControllerForAncestor] titleLabel] text];
				else
					title = [[(MiniPlayerViewController*)[self _viewControllerForAncestor] nowPlayingItemTitleLabel] text];

				if([title hasSuffix: @" 🅴"])
					title = [title substringToIndex: ([title length] - 3)];
				
				dispatch_async(dispatch_get_main_queue(),
				^{
					[colorizer generateColorsForArtwork: image withTitle: title];
				});
			}	
		}
	}
}

%new
- (void)colorize
{
	[MSHookIvar<UIView*>(self, "radiosityView") setHidden: YES]; //UIImageView inside NowPlayingContentView behind artwork
}

%end

// -------------------------------------- ContextualActionsButton  ------------------------------------------------

%hook ContextualActionsButton

%new
- (void)colorize
{
	if([self tintColor] != [colorizer primaryColor])
	{
		[self setCustomTintColor: [colorizer primaryColor]];
		[self setTintColor: [colorizer primaryColor]];

		UIImageView *ellipsisImageView = MSHookIvar<UIImageView*>(self, "ellipsisImageView");
		[ellipsisImageView setCustomTintColor: [colorizer backgroundColor]];
		[ellipsisImageView setTintColor: [colorizer backgroundColor]];
	}
}

%end

// -------------------------------------- PlayerTimeControl  ------------------------------------------------

%hook PlayerTimeControl

%new
- (void)colorize
{
	if([self tintColor] != [colorizer primaryColor])
	{
		[self setCustomTintColor: [colorizer primaryColor]];
		[self setTintColor: [colorizer primaryColor]];

		MSHookIvar<UIColor*>(self, "trackingTintColor") = [colorizer primaryColor];

		[MSHookIvar<UILabel*>(self, "remainingTimeLabel") setCustomTextColor: [colorizer primaryColor]];
		[MSHookIvar<UILabel*>(self, "remainingTimeLabel") setTextColor: [colorizer primaryColor]];
		[MSHookIvar<UIView*>(self, "remainingTrack") setCustomBackgroundColor: [colorizer secondaryColor]];
		[MSHookIvar<UIView*>(self, "remainingTrack") setBackgroundColor: [colorizer secondaryColor]];
		[MSHookIvar<UIView*>(self, "knobView") setCustomBackgroundColor: [colorizer primaryColor]];
		[MSHookIvar<UIView*>(self, "knobView") setBackgroundColor: [colorizer primaryColor]];
	}
}

%end

// -------------------------------------- NowPlayingTransportButton  ------------------------------------------------

%hook NowPlayingTransportButton

- (void)setImage: (id)arg1 forState: (unsigned long long)arg2
{
	%orig([(UIImage*)arg1 imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate], arg2);
}

%new
- (void)colorize
{
	if([[self imageView] tintColor] != [colorizer primaryColor])
	{
		[[self imageView] setCustomTintColor: [colorizer primaryColor]];
		[[self imageView] setTintColor: [colorizer primaryColor]];
		[[[self imageView] layer] setCompositingFilter: 0];

		[MSHookIvar<UIView*>(self, "highlightIndicatorView") setBackgroundColor: [colorizer primaryColor]];
	}
}

%end

// -------------------------------------- MPVolumeSlider  ------------------------------------------------

%hook MPVolumeSlider

%new
- (void)colorize
{
	if([self tintColor] != [colorizer primaryColor])
	{
		[self setCustomTintColor: [colorizer primaryColor]];
		[self setTintColor: [colorizer primaryColor]];

		[[self _minValueView] setTintColor: [colorizer primaryColor]];
		[[self _maxValueView] setTintColor: [colorizer primaryColor]];

		[self setCustomMinimumTrackTintColor: [colorizer primaryColor]];
		[self setMinimumTrackTintColor: [colorizer primaryColor]];
		[self setCustomMaximumTrackTintColor: [colorizer secondaryColor]];
		[self setMaximumTrackTintColor: [colorizer secondaryColor]];

		[[self thumbView] setCustomTintColor: [colorizer primaryColor]];
		[[self thumbView] setTintColor: [colorizer primaryColor]];
		[[[self thumbView] layer] setShadowColor: [colorizer primaryColor].CGColor];
		if([[self thumbImageForState: UIControlStateNormal] renderingMode] != UIImageRenderingModeAlwaysTemplate)
			[self setThumbImage: [[self thumbImageForState: UIControlStateNormal] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate] forState: UIControlStateNormal];
	}
}

%end

// -------------------------------------- MiniPlayerViewController  ------------------------------------------------

%hook MiniPlayerViewController

- (void)viewDidLayoutSubviews
{
	%orig;
	[self colorize];
}

- (void)controller: (id)arg1 defersResponseReplacement: (id)arg2
{
	%orig;
	dispatch_async(dispatch_get_main_queue(),
	^{
		[self colorize];
	});
}

%new
- (void)colorize
{
	if([colorizer backgroundColor])
	{
		[[self view] setCustomBackgroundColor: [colorizer backgroundColor]];
		[[self view] setBackgroundColor: [colorizer backgroundColor]];

		[[[self nowPlayingItemTitleLabel] layer] setCompositingFilter: 0];
		[[self nowPlayingItemTitleLabel] _setTextColorFollowsTintColor: NO];
		[[self nowPlayingItemTitleLabel] setTextColor: [colorizer primaryColor]];

		[[self nowPlayingItemRouteLabel] _setTextColorFollowsTintColor: NO];
		[[self nowPlayingItemRouteLabel] setTextColor: [colorizer secondaryColor]];
		
		[[self playPauseButton] colorize];
		[[self skipButton] colorize];
	}
}

%end

// -------------------------------------- QUEUE STUFF  ------------------------------------------------

%hook NowPlayingQueueViewController

- (id)init
{
	self = %orig;
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(colorize) name: @"MusicArtworkChanged" object: nil];
	return self;
}

- (void)viewDidLayoutSubviews
{
	%orig;
	[self colorize];
}

%new
- (void)colorize
{
	[MSHookIvar<NowPlayingQueueHeaderView*>(self, "upNextHeader") colorize];
	[MSHookIvar<NowPlayingHistoryHeaderView*>(self, "historyHeader") colorize];
}

%end

%hook NowPlayingHistoryHeaderView

- (void)setBackgroundColor: (UIColor*)color
{
	if([colorizer backgroundColor])
		%orig([colorizer backgroundColor]);
	else 
		%orig;
}

%new
- (void)colorize
{
	if([colorizer backgroundColor])
	{
		[UIView animateWithDuration: [colorizer backgroundColorChangeDuration] animations:
		^{
			[(UIView*)self setBackgroundColor: [colorizer backgroundColor]];
		}
		completion: nil];
		
		for (UIView *subview in [self subviews])
		{
			if([subview isKindOfClass: %c(UILabel)]) [(UILabel*)subview setTextColor: [colorizer primaryColor]];
			if([subview isKindOfClass: %c(UIButton)]) [(UIButton*)subview setTintColor: [colorizer secondaryColor]];
		}
	}
}

%end

%hook NowPlayingQueueHeaderView

- (void)setBackgroundColor: (UIColor*)color
{
	if([colorizer backgroundColor]) 
		%orig([colorizer backgroundColor]);
	else 
		%orig;
}

- (void)viewDidLayoutSubviews
{
	%orig;
	[self colorize];
}

%new
- (void)colorize
{
	if([colorizer backgroundColor])
	{
		if([(UIView*)self backgroundColor] != [colorizer backgroundColor])
		{
			[UIView animateWithDuration: [colorizer backgroundColorChangeDuration] animations:
			^{
				[(UIView*)self setBackgroundColor: [colorizer backgroundColor]];
			}
			completion: nil];
		}

		[MSHookIvar<UILabel*>(self, "titleLabel") setTextColor: [colorizer primaryColor]];
		[MSHookIvar<MPButton*>(self, "subtitleButton") setTintColor: [colorizer secondaryColor]];

		MPButton *shuffleButton = MSHookIvar<MPButton*>(self, "shuffleButton");
		[shuffleButton setSpecialButton: @3];
		[shuffleButton updateButtonColor];

		MPButton *repeatButton = MSHookIvar<MPButton*>(self, "repeatButton");
		[repeatButton setSpecialButton: @3];
		[repeatButton updateButtonColor];
	}
}

%end

%hook QueueGradientView

- (void)layoutSubviews
{
	%orig;
	[self setHidden: YES];
}

%end

// -------------------------------------- SET 3 COLUMNS ALBUMS - IPHONE ONLY  ------------------------------------------------

%group _3ColumnsAlbumsGroup

	%hook UICollectionViewFlowLayout

	- (void)setItemSize: (CGSize)arg
	{
		%orig(CGSizeMake(screenWidth / 4, arg.height * 0.7));
	}

	%end

%end

// -------------------------------------- VIBRATIONS  ------------------------------------------------

%group vibrateMusicAppGroup

	%hook  UITableViewCell

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook UICollectionViewCell

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook UITabBarButton

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook UIButton

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook MPRouteButton

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook UISegmentedControl

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook UITextField

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook _UIButtonBarButton

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook TimeSlider

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

	%hook MPVolumeSlider

	- (void)touchesBegan: (id)arg1 withEvent: (id)arg2
	{
		produceLightVibration();
		%orig;
	}

	%end

%end

// -------------------------------------- NO QUEUE HUD  ------------------------------------------------

// Original tweak by @nahtedetihw: https://github.com/nahtedetihw/MusicQueueBeGone

%group hideQueueHUDGroup

	%hook ContextActionsHUDViewController

	- (void)viewDidLoad
	{

	}
		
	%end

%end

void initMusicApp()
{
	@autoreleasepool
	{
		preferences = [MusicPreferences sharedInstance];
		colorizer = [Colorizer sharedInstance];

		isNotchediPhone = [NOTCHED_IPHONES containsObject: getDeviceModel()];
		
		if([preferences _3AlbumsPerLine] && !IS_iPAD)
		{
			screenWidth = [[UIScreen mainScreen] bounds].size.width;
			%init(_3ColumnsAlbumsGroup);
		} 

		if([preferences vibrateMusicApp] && !IS_iPAD) 
			%init(vibrateMusicAppGroup, TimeSlider = NSClassFromString(@"MusicApplication.PlayerTimeControl"));

		if([preferences hideQueueHUD]) 
			%init(hideQueueHUDGroup, ContextActionsHUDViewController = NSClassFromString(@"MusicApplication.ContextActionsHUDViewController"));

		if([preferences colorizeMusicApp])
			%init(NowPlayingContentView = NSClassFromString(@"MusicApplication.NowPlayingContentView"),
				PlayerTimeControl = NSClassFromString(@"MusicApplication.PlayerTimeControl"),
				NowPlayingTransportButton = NSClassFromString(@"MusicApplication.NowPlayingTransportButton"),
				ContextualActionsButton = NSClassFromString(@"MusicApplication.ContextualActionsButton"),
				NowPlayingViewController = NSClassFromString(@"MusicApplication.NowPlayingViewController"),
				MiniPlayerViewController = NSClassFromString(@"MusicApplication.MiniPlayerViewController"),
				NowPlayingQueueViewController = NSClassFromString(@"MusicApplication.NowPlayingQueueViewController"),
				NowPlayingQueueHeaderView = NSClassFromString(@"MusicApplication.NowPlayingQueueHeaderView"),
				NowPlayingHistoryHeaderView = NSClassFromString(@"MusicApplication.NowPlayingHistoryHeaderView"),
				QueueGradientView = NSClassFromString(@"MusicApplication.QueueGradientView"));
	}
}