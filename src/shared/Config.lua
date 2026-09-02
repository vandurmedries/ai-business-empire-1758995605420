--!strict

local Config = {
	Version = "0.2.0",
	ExperienceName = "AI Founder Empire",

	-- Native mode is the default. No Render, Railway, Vercel, or external secret is required.
	BackendBaseUrl = "",
	BackendSecretName = "AI_BUSINESS_BACKEND_SECRET",
	BackendEnabled = false,
	BackendConfigRefreshSeconds = 300,
	BackendTelemetryFlushSeconds = 30,
	BackendTelemetryBatchSize = 50,

	DataStoreName = "AI_FOUNDER_EMPIRE_PLAYER_V1",
	AutoSaveSeconds = 60,
	MaximumRememberedReceipts = 100,

	InitialData = {
		Cash = 250,
		LifetimeRevenue = 0,
		Customers = 0,
		Reputation = 50,
		Level = 1,
		XP = 0,
		TutorialStep = 0,
		CompletedMissions = 0,
		Departments = {
			Product = 1,
			Marketing = 1,
			Sales = 1,
		},
		Boosts = {
			FocusCharges = 0,
			RevenueMultiplierUntil = 0,
		},
		ActiveMission = nil,
		ProcessedReceipts = {},
	},

	Departments = {
		Product = {
			DisplayName = "Product",
			BaseUpgradeCost = 120,
			CostGrowth = 1.55,
			RevenueWeight = 5,
		},
		Marketing = {
			DisplayName = "Marketing",
			BaseUpgradeCost = 100,
			CostGrowth = 1.52,
			RevenueWeight = 4,
		},
		Sales = {
			DisplayName = "Sales",
			BaseUpgradeCost = 110,
			CostGrowth = 1.54,
			RevenueWeight = 5,
		},
	},

	CoreLoop = {
		CycleCooldownSeconds = 8,
		AutomationCooldownMultiplier = 0.7,
		BaseRevenue = 8,
		MinimumRevenue = 5,
		MaximumSingleCycleRevenue = 100000,
		LevelXPBase = 100,
		FocusMultiplier = 1.5,
		TimedBoostMultiplier = 2,
		FounderClubMultiplier = 1.1,
	},

	Mission = {
		RequestCooldownSeconds = 20,
		MaximumDurationMinutes = 1440,
		MaximumRewardCash = 5000,
		FounderClubRewardMultiplier = 1.1,
		AllowedTargets = {
			RunCycles = true,
			EarnCash = true,
			GainCustomers = true,
			UpgradeDepartment = true,
			ImproveReputation = true,
		},
	},

	LiveConfigDefaults = {
		ExperimentId = "control",
		Variant = "control",
		TutorialHintVariant = "step_by_step",
		MissionPromptVariant = "progress_first",
		ValueDemoEnabled = true,
		CycleRewardMultiplier = 1,
		CyclePacingMultiplier = 1,
		ShopOrder = {
			"FounderClub",
			"AutomationPro",
			"ExecutiveDashboard",
			"StarterCapital",
			"FocusBoost",
			"RevenueSprint",
		},
	},

	-- Create these assets in Creator Hub, then replace the zero/empty placeholders.
	Monetization = {
		DeveloperProducts = {
			StarterCapital = 0,
			FocusBoost = 0,
			RevenueSprint = 0,
		},
		Passes = {
			AutomationPro = 0,
			ExecutiveDashboard = 0,
		},
		Subscriptions = {
			FounderClub = "",
		},
		Grants = {
			StarterCapitalCash = 1500,
			FocusBoostCharges = 5,
			RevenueSprintSeconds = 15 * 60,
		},
		Offers = {
			StarterCapital = {
				DisplayName = "Starter Capital",
				Benefit = "+1,500 company cash",
				Kind = "DeveloperProduct",
			},
			FocusBoost = {
				DisplayName = "Founder Focus",
				Benefit = "5 focused revenue cycles",
				Kind = "DeveloperProduct",
			},
			RevenueSprint = {
				DisplayName = "Revenue Sprint",
				Benefit = "2× cycle revenue for 15 minutes",
				Kind = "DeveloperProduct",
			},
			AutomationPro = {
				DisplayName = "Automation Pro",
				Benefit = "Auto-run and 30% shorter cycle cooldown",
				Kind = "GamePass",
			},
			ExecutiveDashboard = {
				DisplayName = "Executive Dashboard",
				Benefit = "Advanced company efficiency metrics",
				Kind = "GamePass",
			},
			FounderClub = {
				DisplayName = "Founder Club",
				Benefit = "+10% revenue and mission rewards while subscribed",
				Kind = "Subscription",
			},
		},
	},

	HardPolicy = {
		AllowExternalPurchaseLinks = false,
		AllowPaidRandomRewards = false,
		AllowAutonomousPriceChanges = false,
		AllowAutonomousPublishing = false,
		AllowAutonomousAdSpend = false,
		AllowSafeLiveConfigExperiments = true,
	},
}

return table.freeze(Config)
