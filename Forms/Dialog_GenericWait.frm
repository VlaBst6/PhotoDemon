VERSION 5.00
Begin VB.Form FormWait 
   Appearance      =   0  'Flat
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Please wait a moment..."
   ClientHeight    =   2535
   ClientLeft      =   45
   ClientTop       =   315
   ClientWidth     =   9015
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   9.75
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   169
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   601
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
   Visible         =   0   'False
   Begin VB.Timer tmrProgBar 
      Interval        =   50
      Left            =   8880
      Top             =   120
   End
   Begin VB.PictureBox picProgBar 
      Appearance      =   0  'Flat
      BackColor       =   &H80000005&
      BorderStyle     =   0  'None
      ForeColor       =   &H80000008&
      Height          =   495
      Left            =   120
      ScaleHeight     =   33
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   585
      TabIndex        =   0
      Top             =   840
      Width           =   8775
   End
   Begin PhotoDemon.pdLabel lblWaitTitle 
      Height          =   405
      Left            =   240
      Top             =   240
      Width           =   8490
      _extentx        =   0
      _extenty        =   0
      alignment       =   2
      caption         =   "please wait"
      fontbold        =   -1  'True
      fontsize        =   12
      forecolor       =   9437184
   End
   Begin PhotoDemon.pdLabel lblWaitDescription 
      Height          =   960
      Left            =   240
      Top             =   1560
      Visible         =   0   'False
      Width           =   8490
      _extentx        =   14975
      _extenty        =   1905
      alignment       =   2
      caption         =   ""
      forecolor       =   9437184
      layout          =   1
   End
End
Attribute VB_Name = "FormWait"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

'System progress bar control
Private sysProgBar As cProgressBarOfficial

Private Sub Form_Load()

    Set sysProgBar = New cProgressBarOfficial
    sysProgBar.CreateProgressBar picProgBar.hWnd, 0, 0, picProgBar.ScaleWidth, picProgBar.ScaleHeight, True, True, True, True
    sysProgBar.Max = 100
    sysProgBar.Min = 0
    sysProgBar.Value = 0
    sysProgBar.Marquee = True
    sysProgBar.Value = 0
    
    Interface.ApplyThemeAndTranslations Me
    
    'Turn on the progress bar timer, which is used to move the marquee progress bar.
    ' (This is no longer required, thankfully.)
    'tmrProgBar.Enabled = True
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    tmrProgBar.Enabled = False
End Sub

Private Sub tmrProgBar_Timer()

    sysProgBar.Value = sysProgBar.Value + 1
    If sysProgBar.Value = sysProgBar.Max Then sysProgBar.Value = sysProgBar.Min
    
    sysProgBar.Refresh
    
End Sub

