--!strict

export type DepartmentName = "Product" | "Marketing" | "Sales"

export type Departments = {
	Product: number,
	Marketing: number,
	Sales: number,
}

export type Boosts = {
	FocusCharges: number,
	RevenueMultiplierUntil: number,
}

export type Mission = {
	Id: string,
	TemplateId: string,
	Title: string,
	Brief: string,
	TargetMetric: string,
	TargetValue: number,
	Progress: number,
	RewardCash: number,
	IssuedAt: number,
	ExpiresAt: number,
	Source: string,
}

export type PlayerData = {
	SchemaVersion: number,
	Cash: number,
	LifetimeRevenue: number,
	Customers: number,
	Reputation: number,
	Level: number,
	XP: number,
	TutorialStep: number,
	CompletedMissions: number,
	Departments: Departments,
	Boosts: Boosts,
	ActiveMission: Mission?,
	ProcessedReceipts: { string },
	UpdatedAt: number,
}

export type Entitlements = {
	AutomationPro: boolean,
	ExecutiveDashboard: boolean,
	FounderClub: boolean,
}

return {}
