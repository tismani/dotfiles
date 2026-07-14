{ lib, pkgs, inputs, ... }: {

  networking.hostName = "nightfury";
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "mani";

  # TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      launchanim = false;
      show-process-indicators = true;
      orientation = "bottom";
      tilesize = 36;
      minimize-to-application = true;
      mineffect = "scale";
    };
    finder.AppleShowAllExtensions = true;
    finder.FXPreferredViewStyle = "clmv"; # column view
    trackpad.Clicking = true;
    trackpad.TrackpadRightClick = true; # Optional: enables two-finger tap for right click
    NSGlobalDomain."com.apple.mouse.tapBehavior" = 1;
    NSGlobalDomain.KeyRepeat = 2;
    NSGlobalDomain.ApplePressAndHoldEnabled = false;
    NSGlobalDomain.AppleICUForce24HourTime = true;
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
    NSGlobalDomain.PMPrintingExpandedStateForPrint = true;
    NSGlobalDomain.PMPrintingExpandedStateForPrint2 = true;
    NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;
    menuExtraClock = {
      Show24Hour = true;
      ShowAMPM = false;
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [
      {
        # Caps Lock → Left Control
        HIDKeyboardModifierMappingSrc = 30064771129;  # 0x700000039
        HIDKeyboardModifierMappingDst = 30064771296;  # 0x7000000E0
      }
      {
        # Left Control → Caps Lock
        HIDKeyboardModifierMappingSrc = 30064771296;  # 0x7000000E0
        HIDKeyboardModifierMappingDst = 30064771129;  # 0x700000039
      }
    ];
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = false;
      ShowRemovableMediaOnDesktop = true;
      _FXSortFoldersFirst = true;
      # search the current folder by default
      FXDefaultSearchScope = "SCcf";
      DisableAllAnimations = true;
      NewWindowTarget = "PfDe";
      NewWindowTargetPath = "file:///Users/mani/Desktop/";
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowStatusBar = true;
      ShowPathbar = true;
      WarnOnEmptyTrash = false;
    };
    "com.apple.desktopservices" = {
      # Avoid creating .DS_Store files on network or USB volumes
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
    "com.apple.HIToolbox" = {
      # Completely disable Caps Lock functionality
      AppleFnUsageType = 1; # Enable Fn key functionality
      AppleKeyboardUIMode = 3;
    };

    "com.apple.ActivityMonitor" = {
      OpenMainWindow = true;
      IconType = 5;
      SortColumn = "CPUUsage";
      SortDirection = 0;
    };
    "com.apple.Safari" = {
      # Privacy: don’t send search queries to Apple
      UniversalSearchEnabled = false;
      SuppressSearchSuggestions = true;
    };
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
    };
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      # Check for software updates daily, not just once per week
      ScheduleFrequency = 1;
      # Download newly available updates in background
      AutomaticDownload = 1;
      # Install System data files & security updates
      CriticalUpdateInstall = 1;
    };
    "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
    # Prevent Photos from opening automatically when devices are plugged in
    "com.apple.ImageCapture".disableHotPlug = true;
    # Turn on app auto-update
    "com.apple.commerce".AutoUpdate = true;
    "com.googlecode.iterm2".PromptOnQuit = false;
    "com.google.Chrome" = {
      AppleEnableSwipeNavigateWithScrolls = true;
      DisablePrintPreview = true;
      PMPrintingExpandedStateForPrint2 = true;
    };
  };

  environment.systemPackages = with pkgs; [
    mas
  ];

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    global.autoUpdate = true;

    casks = [
     	"firefox"
      "google-chrome"
     	"wezterm"
     	"raycast"
     	"octarine"
      "stats"
      "protonvpn"
      "warp"
      "vlc"
      "claude"
      "bettertouchtool"
      "coconutbattery"
      "naps2"
      "voiceink"
      "wifiman"
      "synology-drive"
      "docker-desktop" # virtualisation.docker.enable is not available on nix-darwin
    ];

    masApps = {
      "Amphetamine" = 937984704;
      "Bitwarden" = 1352778147;
      "rCmd" = 1596283165;
      "Tailscale" = 1475387142;
      "The Unarchiver" = 425424353;
      "Snippety" = 1530751461;
      "FE File Explorer Pro" = 1466198841;
      "WhatsApp Messenger" = 310633997;
      "uBlock Origin Lite" = 6745342698;
      "Infuse" = 1136220934;
    };
  };

  users.users.mani = {
    name = "mani";
    home = "/Users/mani";
  };
  home-manager.users.mani.home.homeDirectory = lib.mkForce "/Users/mani";

  system.stateVersion = 5;
}
