--!strict

const Document = require("@self/Document")
const Policy = require("@self/Policy")
const Style = require("@self/Style")
const Text = require("@self/Text")
const Renderer = require("@self/Renderer")
const Class = require("@self/Class")
const Flatten = require("@self/Flatten")
const Incremental = require("@self/Incremental")
const Layout = require("@self/Layout")
const Code = require("@self/Code")

export type Node = Document.Node
export type Attribute = Document.Attribute

export type IntentFlag = Policy.IntentFlag
export type IntentsValue = Policy.IntentsValue
export type Intents = Policy.Intents
export type Denied = Policy.Denied
export type TextSizeLimits = Policy.TextSizeLimits
export type Limits = Policy.Limits
export type LimitsData = Policy.LimitsData
export type AssetFilter = Policy.AssetFilter
export type Rendering = Policy.Rendering
export type RenderingData = Policy.RenderingData
export type RenderingName = Policy.RenderingName
export type Whitespace = Policy.Whitespace
export type Preset = Policy.Preset

export type Gradient = Style.Gradient
export type EffectData = Style.EffectData
export type EffectFrame = Style.EffectFrame
export type EffectUpdate = Style.EffectUpdate
export type EffectOffset = Style.EffectOffset
export type StrokeData = Style.StrokeData
export type MarkData = Style.MarkData
export type IndentData = Style.IndentData
export type ContainerData = Style.ContainerData
export type Style = Style.Style
export type Theme = Style.Theme
export type Syntax = Style.Syntax

export type Joint = Text.Joint
export type GlyphTable = Text.GlyphTable
export type Token = Text.Token
export type Line = Text.Line
export type Region = Text.Region
export type Entry = Text.Entry
export type Spans = Text.Spans
export type Ledger = Text.Ledger

export type OutlineData = Renderer.OutlineData
export type CopyData = Renderer.CopyData
export type MotionData = Renderer.MotionData
export type ContentData = Renderer.ContentData
export type LookData = Renderer.LookData
export type DecorData = Renderer.DecorData
export type Record = Renderer.Record
export type RectData = Renderer.RectData
export type RoundData = Renderer.RoundData
export type PaintData = Renderer.PaintData
export type Layer = Renderer.Layer
export type Run = Renderer.Run
export type BackdropPiece = Renderer.BackdropPiece
export type Coverage = Renderer.Coverage
export type RunColumns = Renderer.RunColumns
export type RowColumns = Renderer.RowColumns
export type BlockData = Renderer.BlockData
export type MetricsData = Renderer.MetricsData
export type KeyData = Renderer.KeyData
export type WidthData = Renderer.WidthData
export type Shape = Renderer.Shape
export type PendingData = Renderer.PendingData
export type StagedData = Renderer.StagedData
export type CursorData = Renderer.CursorData
export type ShelfData = Renderer.ShelfData
export type SettingData = Renderer.SettingData
export type CommitData = Renderer.CommitData
export type Memory = Renderer.Memory
export type Resizer = Renderer.Resizer
export type Applier = Renderer.Applier
export type OptionData = Renderer.OptionData
export type DocumentData = Renderer.DocumentData
export type InstanceData = Renderer.InstanceData
export type BackdropData = Renderer.BackdropData
export type ObjectData = Renderer.ObjectData
export type TroveData = Renderer.TroveData
export type GenerationData = Renderer.GenerationData
export type ScaleData = Renderer.ScaleData
export type HostData = Renderer.HostData
export type DeveloperData = Renderer.DeveloperData
export type NativeData = Renderer.NativeData
export type AnimationData = Renderer.AnimationData
export type DecorationData = Renderer.DecorationData
export type BoundsData = Renderer.BoundsData
export type CullData = Renderer.CullData
export type Fields = Renderer.Fields

export type ClassDefinition = Class.ClassDefinition

export type TreeData = Flatten.TreeData
export type DraftData = Flatten.DraftData
export type RangeData = Flatten.RangeData
export type CountData = Flatten.CountData
export type LimitData = Flatten.LimitData
export type AccessData = Flatten.AccessData
export type EmitData = Flatten.EmitData
export type InternData = Flatten.InternData
export type ReuseData = Flatten.ReuseData
export type NestingData = Flatten.NestingData
export type FlagData = Flatten.FlagData
export type FlattenContext = Flatten.FlattenContext
export type FlattenHandler = Flatten.FlattenHandler
export type FlattenApplier = Flatten.FlattenApplier

export type Window = Incremental.Window
export type CutData = Incremental.CutData
export type Change = Incremental.Change
export type Workspace = Incremental.Workspace

export type BreakData = Layout.BreakData
export type Paragraph = Layout.Paragraph
export type PassData = Layout.PassData
export type TotalData = Layout.TotalData
export type RetainData = Layout.RetainData
export type Sheet = Layout.Sheet
export type Model = Layout.Model
export type ProblemData = Layout.ProblemData
export type MeasuredData = Layout.MeasuredData
export type KnownData = Layout.KnownData
export type GoalData = Layout.GoalData
export type CrawlData = Layout.CrawlData
export type ModelData = Layout.ModelData
export type EndData = Layout.EndData
export type Bracket = Layout.Bracket
export type Solution = Layout.Solution
export type Memo = Layout.Memo

export type SizeData = Code.SizeData
export type PanelData = Code.PanelData
export type CodePlan = Code.CodePlan

const Element = require("@self/Element")

export type Element = Element.Element
export type ElementState = Element.ElementState
export type BindHandlers = Element.BindHandlers
export type Binding = Element.Binding
export type PointerData = Element.PointerData
export type ElementsData = Element.ElementsData

const Markdown = require("@self/Markdown")

export type MarkdownDocument = Markdown.Document

return {}
