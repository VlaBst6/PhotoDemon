VERSION 5.00
Begin VB.Form FormBrightnessContrast 
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Brightness/Contrast"
   ClientHeight    =   6540
   ClientLeft      =   45
   ClientTop       =   285
   ClientWidth     =   12075
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
   ScaleWidth      =   805
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.pdCommandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5790
      Width           =   12075
      _extentx        =   21299
      _extenty        =   1323
   End
   Begin PhotoDemon.pdCheckBox chkSample 
      Height          =   330
      Left            =   6120
      TabIndex        =   3
      Top             =   3840
      Width           =   5775
      _extentx        =   10186
      _extenty        =   582
      caption         =   "sample image for true contrast (slower but more accurate)"
   End
   Begin PhotoDemon.pdFxPreviewCtl pdFxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   4
      Top             =   120
      Width           =   5625
      _extentx        =   9922
      _extenty        =   9922
   End
   Begin PhotoDemon.pdSlider sltBright 
      Height          =   705
      Left            =   6000
      TabIndex        =   1
      Top             =   1680
      Width           =   5895
      _extentx        =   10398
      _extenty        =   1270
      caption         =   "brightness"
      min             =   -255
      max             =   255
      value           =   -10
   End
   Begin PhotoDemon.pdSlider sltContrast 
      Height          =   705
      Left            =   6000
      TabIndex        =   2
      Top             =   2760
      Width           =   5895
      _extentx        =   10398
      _extenty        =   1270
      caption         =   "contrast"
      min             =   -100
      max             =   100
      value           =   10
   End
End
Attribute VB_Name = "FormBrightnessContrast"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Brightness and Contrast Handler
'Copyright 2001-2016 by Tanner Helland
'Created: 2/6/01
'Last updated: 16/February/16
'Last update: use this dialog to test some new theming options; Form_Load may end up being preferable for theming
'              steps, after all...
'
'The central brightness/contrast handler.  Everything is done via look-up tables, so it's extremely fast.
' It's all linear (not logarithmic; sorry). Maybe someday I'll change that, maybe not... honestly, I probably
' won't, since brightness and contrast are such stupid functions anyway.  People should be using levels or
' curves or white balance instead!
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'While previewing, we don't need to repeatedly sample contrast.  Just do it once and store the value.
Private m_previewHasSampled As Boolean
Private m_previewSampledContrast As Long

'Update the preview when the "sample contrast" checkbox value is changed
Private Sub chkSample_Click()
    UpdatePreview
End Sub

'Single routine for modifying both brightness and contrast.  Brightness is in the range (-255,255) while
' contrast is (-100,100).  Optionally, the image can be sampled to obtain a true midpoint for the contrast function.
Public Sub BrightnessContrast(ByVal Bright As Long, ByVal Contrast As Double, Optional ByVal TrueContrast As Boolean = True, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As pdFxPreviewCtl)
    
    If Not toPreview Then Message "Adjusting image brightness..."
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim ImageData() As Byte
    Dim tmpSA As SAFEARRAY2D
    
    prepImageData tmpSA, toPreview, dstPic
    CopyMemory ByVal VarPtrArray(ImageData()), VarPtr(tmpSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim QuickVal As Long, qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    progBarCheck = FindBestProgBarValue()
    
    'If the brightness value is anything but 0, process it
    If (Bright <> 0) Then
        
        If Not toPreview Then
        
            Message "Adjusting image brightness..."
        
            'Because contrast and brightness are handled together, set the progress bar maximum value
            ' contingent on whether we're handling just brightness, or both brightness AND contrast.
            If (Contrast <> 0) Then
                SetProgBarMax finalX * 2
                progBarCheck = FindBestProgBarValue()
            End If
            
        End If
        
        'Look-up tables work brilliantly for brightness
        Dim BrightTable(0 To 255) As Byte
        Dim BTCalc As Long
        
        For x = 0 To 255
            BTCalc = x + Bright
            If BTCalc > 255 Then BTCalc = 255
            If BTCalc < 0 Then BTCalc = 0
            BrightTable(x) = CByte(BTCalc)
        Next x
        
        'Loop through each pixel in the image, converting values as we go
        For x = initX To finalX
            QuickVal = x * qvDepth
        For y = initY To finalY
            
            'Use the look-up table to perform an ultra-quick brightness adjustment
            ImageData(QuickVal, y) = BrightTable(ImageData(QuickVal, y))
            ImageData(QuickVal + 1, y) = BrightTable(ImageData(QuickVal + 1, y))
            ImageData(QuickVal + 2, y) = BrightTable(ImageData(QuickVal + 2, y))
            
        Next y
            If toPreview = False Then
                If (x And progBarCheck) = 0 Then
                    If UserPressedESC() Then Exit For
                    SetProgBarVal x
                End If
            End If
        Next x
        
    End If
    
    'If the contrast value is anything but 0, process it
    If (Contrast <> 0) And (Not cancelCurrentAction) Then
    
        'Contrast requires an average value to operate correctly; it works by pushing luminance values away from that average.
        Dim Mean As Long
    
        'Sampled contrast is my invention; traditionally contrast pushes colors toward or away from gray.
        ' I like the option to push the colors toward or away from the image's actual midpoint, which
        ' may not be gray.  For most white-balanced photos the difference is minimal, but for images with
        ' non-traditional white balance, sampled contrast offers better results.
        If TrueContrast Then
        
            If toPreview And m_previewHasSampled Then
            
                Mean = m_previewSampledContrast
            
            Else
            
                If toPreview = False Then Message "Sampling image data to determine true contrast..."
                
                Dim rTotal As Long, gTotal As Long, bTotal As Long
                rTotal = 0
                gTotal = 0
                bTotal = 0
                
                Dim NumOfPixels As Long
                NumOfPixels = 0
                
                For x = initX To finalX
                    QuickVal = x * qvDepth
                For y = initY To finalY
                    rTotal = rTotal + ImageData(QuickVal + 2, y)
                    gTotal = gTotal + ImageData(QuickVal + 1, y)
                    bTotal = bTotal + ImageData(QuickVal, y)
                    NumOfPixels = NumOfPixels + 1
                Next y
                Next x
                
                rTotal = rTotal \ NumOfPixels
                gTotal = gTotal \ NumOfPixels
                bTotal = bTotal \ NumOfPixels
                
                Mean = (rTotal + gTotal + bTotal) \ 3
                
                If toPreview Then
                    m_previewSampledContrast = Mean
                    m_previewHasSampled = True
                End If
            
            End If
                
        'If we're not using true contrast, set the mean to the traditional 127
        Else
            Mean = 127
        End If
            
        
        If Not toPreview Then Message "Adjusting image contrast..."
        
        'Like brightness, contrast works beautifully with look-up tables
        Dim ContrastTable(0 To 255) As Byte, CTCalc As Long
                
        For x = 0 To 255
            CTCalc = x + (((x - Mean) * Contrast) \ 100)
            If CTCalc > 255 Then CTCalc = 255
            If CTCalc < 0 Then CTCalc = 0
            ContrastTable(x) = CByte(CTCalc)
        Next x
        
        'Loop through each pixel in the image, converting values as we go
        For x = initX To finalX
            QuickVal = x * qvDepth
        For y = initY To finalY
            
            'Use the look-up table to perform an ultra-quick brightness adjustment
            ImageData(QuickVal, y) = ContrastTable(ImageData(QuickVal, y))
            ImageData(QuickVal + 1, y) = ContrastTable(ImageData(QuickVal + 1, y))
            ImageData(QuickVal + 2, y) = ContrastTable(ImageData(QuickVal + 2, y))
            
        Next y
            If toPreview = False Then
                If (x And progBarCheck) = 0 Then
                    If UserPressedESC() Then Exit For
                    If Bright <> 0 Then SetProgBarVal x + finalX Else SetProgBarVal x
                End If
            End If
        Next x
        
    End If
    
    'With our work complete, point ImageData() away from the DIB and deallocate it
    CopyMemory ByVal VarPtrArray(ImageData), 0&, 4
    Erase ImageData
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    finalizeImageData toPreview, dstPic

End Sub

'OK button.  Note that the command bar class handles validation, form hiding, and form unload for us.
Private Sub cmdBar_OKClick()
    Process "Brightness and contrast", , buildParams(sltBright, sltContrast, CBool(chkSample.Value)), UNDO_LAYER
End Sub

'Sometimes the command bar will perform actions (like loading a preset) that require an updated preview.  This function
' is fired by the control when it's ready for such an update.
Private Sub cmdBar_RequestPreviewUpdate()
    UpdatePreview
End Sub

'RESET button.  All control default values will be reset according to the rules specified in the pdCommandBar user control
' source.  If we want a different default value applied, we can specify that here.  The important thing to note is
' that THE VALUES VISIBLE IN THE IDE DESIGNER DO NOT MATTER.
Private Sub cmdBar_ResetClick()
    
End Sub

Private Sub Form_Load()

    m_previewHasSampled = 0
    m_previewSampledContrast = 0
    
    'Apply translations and visual themes
    ApplyThemeAndTranslations Me
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

Private Sub sltBright_Change()
    UpdatePreview
End Sub

Private Sub sltContrast_Change()
    UpdatePreview
End Sub

Private Sub UpdatePreview()
    If cmdBar.PreviewsAllowed Then BrightnessContrast sltBright, sltContrast, CBool(chkSample.Value), True, pdFxPreview
End Sub

'If the user changes the position and/or zoom of the preview viewport, the entire preview must be redrawn.
Private Sub pdFxPreview_ViewportChanged()
    UpdatePreview
End Sub






