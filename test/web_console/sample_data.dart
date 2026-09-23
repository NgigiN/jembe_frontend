// The mockups' own sample farm (DESIGN_SPEC §8), so a preview can be laid
// beside the reference screen and compared row for row.
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_invitation.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_member.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';

const sampleCounts = DashboardCounts(
  lands: 2,
  plants: 1,
  seasons: 1,
  harvests: 1,
  animalTypes: 2,
  herds: 2,
);

const sampleTotals = DashboardTotals(
  totalCosts: 15900,
  totalRevenue: 12600,
  profit: -3300,
);

final _day = DateTime(2026, 9, 23, 14, 5);

FeedEntry _entry(
  String type,
  String summary,
  String first,
  String last,
  int daysAgo, [
  int hour = 9,
]) => FeedEntry(
  entityType: type,
  summary: summary,
  loggedByUserId: 1,
  loggedByFirstName: first,
  loggedByLastName: last,
  createdAt: _day.subtract(Duration(days: daysAgo, hours: 14 - hour)),
);

final sampleFeed = [
  _entry('activity', 'Weeding — Maize, West Plot', 'Otieno', 'Baraka', 0, 14),
  _entry('input', 'Broiler feed 50 kg', 'Wanjiku', 'Njeri', 0, 11),
  _entry('herd_activity', 'Milking — Dairy herd (6 cows)', 'Otieno', 'Baraka', 1, 7),
  _entry('revenue', 'Milk sales — Keringet Dairies', 'Kamau', 'Owner', 1, 16),
  _entry('activity', 'Vaccination — Broilers (120)', 'Wanjiku', 'Njeri', 2, 10),
  _entry('activity', 'Top-dressing — Maize, East Plot', 'Otieno', 'Baraka', 3, 8),
  _entry('harvest', 'Maize harvest — West Plot', 'Kamau', 'Owner', 4, 12),
  _entry('input', 'CAN fertilizer 50 kg', 'Kamau', 'Owner', 5, 9),
];

const sampleBreakdown = [
  CostBreakdown(
    category: 'Fertilizer',
    type: 'plant',
    origin: 'Long rains 2026',
    totalCost: 11300,
    percentage: 71,
  ),
  CostBreakdown(
    category: 'Feed',
    type: 'animal',
    origin: 'Broilers',
    totalCost: 3400,
    percentage: 21,
  ),
  CostBreakdown(
    category: 'Veterinary',
    type: 'animal',
    origin: 'Dairy cows',
    totalCost: 1200,
    percentage: 8,
  ),
];

final sampleCostDetails = [
  CostDetail(
    type: 'plant',
    id: 1,
    name: 'Maize \u2014 West Plot',
    category: 'Fertilizer',
    location: 'Long rains 2026',
    startDate: DateTime(2026, 3, 14),
    endDate: DateTime(2026, 9, 30),
    inputCost: 11300,
    activityCost: 0,
    totalCost: 11300,
  ),
  CostDetail(
    type: 'animal',
    id: 2,
    name: 'Broilers',
    category: 'Feed',
    location: 'Chicken house',
    startDate: DateTime(2026, 4),
    inputCost: 3400,
    activityCost: 0,
    totalCost: 3400,
  ),
  CostDetail(
    type: 'animal',
    id: 3,
    name: 'Dairy cows',
    category: 'Veterinary',
    location: 'Dairy herd',
    startDate: DateTime(2026, 2),
    inputCost: 1200,
    activityCost: 0,
    totalCost: 1200,
  ),
];

const _noBreakdown = MonthlySummaryBreakdown(
  costs: MonthlyCostBreakdown(plant: 0, animal: 0, infrastructure: 0),
  revenue: MonthlyRevenueBreakdown(plant: 0, animal: 0),
);

const sampleMonths = [
  MonthlySummary(month: '2026-03', totalCosts: 6800, totalRevenue: 0, profit: -6800, breakdown: _noBreakdown),
  MonthlySummary(month: '2026-04', totalCosts: 3400, totalRevenue: 2100, profit: -1300, breakdown: _noBreakdown),
  MonthlySummary(month: '2026-05', totalCosts: 1200, totalRevenue: 4800, profit: 3600, breakdown: _noBreakdown),
  MonthlySummary(month: '2026-06', totalCosts: 0, totalRevenue: 3200, profit: 3200, breakdown: _noBreakdown),
  MonthlySummary(month: '2026-07', totalCosts: 2300, totalRevenue: 1500, profit: -800, breakdown: _noBreakdown),
  MonthlySummary(month: '2026-08', totalCosts: 900, totalRevenue: 500, profit: -400, breakdown: _noBreakdown),
  MonthlySummary(month: '2026-09', totalCosts: 1300, totalRevenue: 500, profit: -800, breakdown: _noBreakdown),
];

final sampleMembers = [
  FarmMember(
    userId: 1,
    firstName: 'Kamau',
    lastName: 'Owner',
    email: 'kamau@gmail.com',
    role: FarmRole.owner,
    joinedAt: DateTime(2026, 2, 3),
  ),
  FarmMember(
    userId: 2,
    firstName: 'Wanjiku',
    lastName: 'Njeri',
    email: 'wanjiku.njeri@gmail.com',
    role: FarmRole.manager,
    joinedAt: DateTime(2026, 3, 18),
  ),
  FarmMember(
    userId: 3,
    firstName: 'Otieno',
    lastName: 'Baraka',
    email: 'otieno.b@gmail.com',
    role: FarmRole.worker,
    joinedAt: DateTime(2026, 4, 2),
  ),
];

final sampleInvitations = [
  FarmInvitation(
    id: 9,
    email: 'achieng.m@gmail.com',
    role: FarmRole.worker,
    invitedBy: 1,
    expiresAt: DateTime.now().add(const Duration(days: 5)),
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

const sampleFarms = [
  Farm(
    id: 1,
    name: 'Keringet',
    location: 'Nakuru',
    fiscalYearStartMonth: 1,
    ownerUserId: 1,
    successorUserId: null,
    maxMembers: 10,
    role: FarmRole.owner,
    memberCount: 3,
    isDefault: true,
  ),
  Farm(
    id: 2,
    name: 'Kamburu',
    location: "Murang'a",
    fiscalYearStartMonth: 1,
    ownerUserId: 1,
    successorUserId: null,
    maxMembers: 10,
    role: FarmRole.owner,
    memberCount: 1,
    isDefault: false,
  ),
];
