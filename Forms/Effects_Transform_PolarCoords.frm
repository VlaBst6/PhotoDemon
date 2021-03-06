VERSION 5.00
Begin VB.Form FormPolar 
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Polar Coordinate Conversion"
   ClientHeight    =   6540
   ClientLeft      =   -15
   ClientTop       =   225
   ClientWidth     =   12105
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   436
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   807
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.pdButtonStrip btsRender 
      Height          =   1095
      Left            =   6000
      TabIndex        =   6
      Top             =   4200
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1931
      Caption         =   "render emphasis"
   End
   Begin PhotoDemon.pdCheckBox chkSwapXY 
      Height          =   330
      Left            =   6120
      TabIndex        =   1
      Top             =   1590
      Width           =   5670
      _ExtentX        =   10001
      _ExtentY        =   582
      Caption         =   "swap x and y coordinates"
   End
   Begin PhotoDemon.pdCommandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5790
      Width           =   12105
      _ExtentX        =   21352
      _ExtentY        =   1323
      BackColor       =   14802140
   End
   Begin PhotoDemon.pdFxPreviewCtl pdFxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   3
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
      DisableZoomPan  =   -1  'True
   End
   Begin PhotoDemon.pdSlider sltRadius 
      Height          =   705
      Left            =   6000
      TabIndex        =   5
      Top             =   2280
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1270
      Caption         =   "radius (percentage)"
      Min             =   1
      Max             =   100
      Value           =   100
      NotchPosition   =   2
      NotchValueCustom=   100
   End
   Begin PhotoDemon.pdDropDown cboEdges 
      Height          =   375
      Left            =   6120
      TabIndex        =   2
      Top             =   3600
      Width           =   5655
      _ExtentX        =   9975
      _ExtentY        =   661
   End
   Begin PhotoDemon.pdDropDown cboConvert 
      Height          =   375
      Left            =   6120
      TabIndex        =   4
      Top             =   1170
      Width           =   5655
      _ExtentX        =   9975
      _ExtentY        =   661
   End
   Begin PhotoDemon.pdLabel lblTitle 
      Height          =   315
      Index           =   1
      Left            =   6000
      Top             =   3210
      Width           =   5835
      _ExtentX        =   10292
      _ExtentY        =   556
      Caption         =   "if pixels lie outside the image..."
      FontSize        =   12
      ForeColor       =   4210752
   End
   Begin PhotoDemon.pdLabel lblTitle 
      Height          =   315
      Index           =   0
      Left            =   6000
      Top             =   840
      Width           =   5820
      _ExtentX        =   10266
      _ExtentY        =   556
      Caption         =   "conversion"
      FontSize        =   12
      ForeColor       =   4210752
   End
End
Attribute VB_Name = "FormPolar"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Image Polar Coordinate Conversion Tool
'Copyright 2013-2016 by Tanner Helland
'Created: 14/January/13
'Last updated: 23/August/13
'Last update: added command bar, converted the polar coordinate routine itself to operate on any two DIBs
'             (thus making this dialog just a thin wrapper to that function)
'
'This tool allows the user to convert an image between rectangular and polar coordinates.  An optional polar
' inversion technique is also supplied (as this is used by Paint.NET).
'
'The transformation used by this tool is a modified version of a transformation originally written by
' Jerry Huxtable of JH Labs.  Jerry's original code is licensed under an Apache 2.0 license.  You may download his
' original version at the following link (good as of 07 January '13): http://www.jhlabs.com/ip/filters/index.html
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

Private Sub btsRender_Click(ByVal buttonIndex As Long)
    UpdatePreview
End Sub

Private Sub cboConvert_Click()
    UpdatePreview
End Sub

Private Sub chkSwapXY_Click()
    UpdatePreview
End Sub

Private Sub cboEdges_Click()
    UpdatePreview
End Sub

'Convert an image to/from polar coordinates.
' INPUT PARAMETERS FOR CONVERSION:
' 0) Convert rectangular to polar
' 1) Convert polar to rectangular
' 2) Polar inversion
Public Sub ConvertToPolar(ByVal conversionMethod As Long, ByVal swapXAndY As Boolean, ByVal polarRadius As Double, ByVal edgeHandling As Long, ByVal useBilinear As Boolean, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As pdFxPreviewCtl)

    If Not toPreview Then Message "Performing polar coordinate conversion..."
        
    'Create a local array and point it at the pixel data of the current image
    Dim dstSA As SAFEARRAY2D
    prepImageData dstSA, toPreview, dstPic
    
    'Create a second local array.  This will contain the a copy of the current image, and we will use it as our source reference
    ' (This is necessary to prevent converted pixel values from spreading across the image as we go.)
    Dim srcDIB As pdDIB
    Set srcDIB = New pdDIB
    srcDIB.createFromExistingDIB workingDIB
    
    'Use the external function to create a polar coordinate DIB
    If swapXAndY Then
        CreatePolarCoordDIB conversionMethod, polarRadius, edgeHandling, useBilinear, srcDIB, workingDIB, toPreview
    Else
        CreateXSwappedPolarCoordDIB conversionMethod, polarRadius, edgeHandling, useBilinear, srcDIB, workingDIB, toPreview
    End If
    
    srcDIB.eraseDIB
    Set srcDIB = Nothing
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering using the data inside workingDIB
    finalizeImageData toPreview, dstPic
        
End Sub

'OK button
Private Sub cmdBar_OKClick()
    Process "Polar conversion", , buildParams(cboConvert.ListIndex, CBool(chkSwapXY), sltRadius.Value, CLng(cboEdges.ListIndex), CBool(btsRender.ListIndex = 1)), UNDO_LAYER
End Sub

Private Sub cmdBar_RequestPreviewUpdate()
    UpdatePreview
End Sub

Private Sub cmdBar_ResetClick()
    sltRadius.Value = 100
    chkSwapXY.Value = vbUnchecked
    cboEdges.ListIndex = EDGE_ERASE
End Sub

Private Sub Form_Activate()

    'Apply translations and visual themes
    ApplyThemeAndTranslations Me
        
    'Create the preview
    cmdBar.markPreviewStatus True
    UpdatePreview
    
End Sub

Private Sub Form_Load()
    
    'Disable previews until the dialog is fully initialized
    cmdBar.markPreviewStatus False
    
    btsRender.AddItem "speed", 0
    btsRender.AddItem "quality", 1
    btsRender.ListIndex = 1
    
    'I use a central function to populate the edge handling combo box; this way, I can add new methods and have
    ' them immediately available to all distort functions.
    PopDistortEdgeBox cboEdges, EDGE_ERASE
    
    'Populate the polar conversion technique drop-down
    cboConvert.AddItem "Rectangular to polar", 0
    cboConvert.AddItem "Polar to rectangular", 1
    cboConvert.AddItem "Polar inversion", 2
    cboConvert.ListIndex = 0
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

Private Sub sltRadius_Change()
    UpdatePreview
End Sub

'Redraw the on-screen preview of the transformed image
Private Sub UpdatePreview()
    If cmdBar.previewsAllowed Then ConvertToPolar cboConvert.ListIndex, CBool(chkSwapXY), sltRadius.Value, CLng(cboEdges.ListIndex), CBool(btsRender.ListIndex = 1), True, pdFxPreview
End Sub

'If the user changes the position and/or zoom of the preview viewport, the entire preview must be redrawn.
Private Sub pdFxPreview_ViewportChanged()
    UpdatePreview
End Sub








