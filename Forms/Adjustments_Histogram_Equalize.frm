VERSION 5.00
Begin VB.Form FormEqualize 
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Equalize Histogram"
   ClientHeight    =   6555
   ClientLeft      =   45
   ClientTop       =   285
   ClientWidth     =   12090
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
   ScaleHeight     =   437
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   806
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.pdSlider sltRadius 
      Height          =   705
      Left            =   5880
      TabIndex        =   4
      Top             =   4440
      Width           =   6015
      _ExtentX        =   10610
      _ExtentY        =   1244
      Caption         =   "radius"
      Min             =   1
      Max             =   100
      Value           =   1
      GradientColorRight=   1703935
   End
   Begin PhotoDemon.pdButtonStrip btsTarget 
      Height          =   1095
      Left            =   5880
      TabIndex        =   2
      Top             =   720
      Width           =   6015
      _ExtentX        =   10610
      _ExtentY        =   1931
      Caption         =   "target histogram"
   End
   Begin PhotoDemon.pdCommandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5805
      Width           =   12090
      _ExtentX        =   21325
      _ExtentY        =   1323
      BackColor       =   14802140
   End
   Begin PhotoDemon.pdFxPreviewCtl pdFxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   1
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
   End
   Begin PhotoDemon.pdButtonStrip btsMode 
      Height          =   1095
      Left            =   5880
      TabIndex        =   3
      Top             =   1920
      Width           =   6015
      _ExtentX        =   10610
      _ExtentY        =   1931
      Caption         =   "mode"
   End
   Begin PhotoDemon.pdButtonStrip btsKernelShape 
      Height          =   1095
      Left            =   5880
      TabIndex        =   5
      Top             =   3120
      Width           =   6015
      _ExtentX        =   10610
      _ExtentY        =   1931
      Caption         =   "kernel shape"
   End
End
Attribute VB_Name = "FormEqualize"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Histogram Equalization Interface
'Copyright 2012-2016 by Tanner Helland
'Created: 19/September/12
'Last updated: 16/December/15
'Last update: overhaul from the ground up so we can support local histogram operations, multiple luminance types,
'             modernize the code, and enable new optimizations
'
'Module for handling histogram equalization.  As of Dec '15, both global and local modes are supported, and a variety
' of histograms can be generated and analyzed.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'Equalize the red, green, blue, and/or Luminance channels of an image
' (Technically Luminance isn't a channel, but you know what I mean.)
Public Sub EqualizeHistogram(ByVal parameterList As String, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As pdFxPreviewCtl)
    
    'Parse out the parameter list
    Dim cParams As pdParamXML
    Set cParams = New pdParamXML
    cParams.setParamString parameterList
    
    Dim ehTarget As Long, ehMode As Long, ehRadius As Long, kernelShape As PD_PIXEL_REGION_SHAPE
    ehTarget = cParams.GetLong("target", 0&)
    ehMode = cParams.GetLong("mode", 0&)
    ehRadius = cParams.GetLong("radius", 1&)
    kernelShape = cParams.GetLong("kernelShape", PDPRS_Rectangle)
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim ImageData() As Byte
    Dim tmpSA As SAFEARRAY2D
    prepImageData tmpSA, toPreview, dstPic
    CopyMemory ByVal VarPtrArray(ImageData()), VarPtr(tmpSA), 4
    
    'Local histogram equalizing requires a second copy of the source image
    Dim srcDIB As pdDIB
    If ehMode <> 0 Then
        Set srcDIB = New pdDIB
        srcDIB.createFromExistingDIB workingDIB
    End If
    
    'If this is a preview, we need to adjust the kernel radius to match the size of the preview box
    If toPreview Then
        ehRadius = ehRadius * curDIBValues.previewModifier
        If ehRadius < 1 Then ehRadius = 1
    End If
    
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim quickX As Long, qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long, initXStride As Long, finalXStride As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    initXStride = initX * qvDepth
    
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
    finalXStride = finalX * qvDepth
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    If Not toPreview Then
        
        'Global and local modes use different progress calculations
        If ehMode = 0 Then
            SetProgBarMax finalY * 2
            progBarCheck = FindBestProgBarValue()
        Else
            SetProgBarMax finalXStride
            progBarCheck = FindBestProgBarValue()
        End If
    End If
    
    'Compute a histogram scaling factor based on the number of pixels in the image; this lets us calculate how many pixels
    ' should ideally exist in each "bin" of the histogram.
    Dim scaleFactor As Double
    scaleFactor = 255 / (curDIBValues.Width * curDIBValues.Height)
    
    'Color variables
    Dim r As Long, g As Long, b As Long, a As Long
    Dim rFloat As Double, gFloat As Double, bFloat As Double
    Dim h As Double, s As Double, v As Double, vLong As Long
    
    Dim NumOfPixels As Long
    NumOfPixels = 0
    
    Dim rValues() As Long, gValues() As Long, bValues() As Long, aValues() As Long, lValues() As Long
    ReDim rValues(0 To 255) As Long
    ReDim gValues(0 To 255) As Long
    ReDim bValues(0 To 255) As Long
    ReDim aValues(0 To 255) As Long
    ReDim lValues(0 To 255) As Long
    
    Dim rData() As Long, gData() As Long, bData() As Long, lData() As Long
    ReDim rData(0 To 255) As Long
    ReDim gData(0 To 255) As Long
    ReDim bData(0 To 255) As Long
    ReDim lData(0 To 255) As Long
    
    Dim startY As Long, stopY As Long, yStep As Long, i As Long
    
    Dim floatLookup() As Double
    ReDim floatLookup(0 To 255) As Double
    For i = 0 To 255
        floatLookup(i) = i / 255
    Next i
    
    Dim directionDown As Boolean
    directionDown = True
    
    'We now split our code into two branches: a global approach, and a local approach.  These two options require vastly
    ' different code.
    
    'Global histogram
    If ehMode = 0 Then
        
        If Not toPreview Then Message "Analyzing image histogram..."
        
        'Start by generating the initial histogram(s)
        For y = initY To finalY
        For x = initXStride To finalXStride Step qvDepth
            
            'Get the source pixel color values
            b = ImageData(x, y)
            g = ImageData(x + 1, y)
            r = ImageData(x + 2, y)
            
            'Store those values in the correct histogram
            'RGB
            If ehTarget = 0 Then
                rValues(r) = rValues(r) + 1
                gValues(g) = gValues(g) + 1
                bValues(b) = bValues(b) + 1
            
            'Luminance
            Else
                a = Colors.getHQLuminance(r, g, b)
                lValues(a) = lValues(a) + 1
            End If
            
        Next x
            If Not toPreview Then
                If (y And progBarCheck) = 0 Then SetProgBarVal y
            End If
        Next y
        
        'With the histograms successfully calculated, it's now time to equalize them
        'RGB
        If ehTarget = 0 Then
        
            rData(0) = CDbl(rValues(0)) * scaleFactor
            For i = 1 To 255
                rData(i) = CDbl(rData(i - 1)) + (scaleFactor * CDbl(rValues(i)))
            Next i
            
            gData(0) = CDbl(gValues(0)) * scaleFactor
            For i = 1 To 255
                gData(i) = CDbl(gData(i - 1)) + (scaleFactor * CDbl(gValues(i)))
            Next i
            
            bData(0) = CDbl(bValues(0)) * scaleFactor
            For i = 1 To 255
                bData(i) = CDbl(bData(i - 1)) + (scaleFactor * CDbl(bValues(i)))
            Next i
            
            'Clamp all lookup table values
            For i = 0 To 255
                If rData(i) > 255 Then rData(i) = 255
                If gData(i) > 255 Then gData(i) = 255
                If bData(i) > 255 Then bData(i) = 255
            Next i
            
        'Luminance
        Else
        
            lData(0) = CDbl(lValues(0)) * scaleFactor
            For i = 1 To 255
                lData(i) = CDbl(lData(i - 1)) + (scaleFactor * CDbl(lValues(i)))
            Next i
            
            For i = 0 To 255
                If lData(i) > 255 Then lData(i) = 255
            Next i
        
        End If
        
        'Apply the new histogram to the image
        If Not toPreview Then Message "Equalizing image..."
        
        For y = initY To finalY
        For x = initXStride To finalXStride Step qvDepth
        
            'Get the source RGB values
            b = ImageData(x, y)
            g = ImageData(x + 1, y)
            r = ImageData(x + 2, y)
            
            'Apply new values
            If ehTarget = 0 Then
                ImageData(x, y) = bData(b)
                ImageData(x + 1, y) = gData(g)
                ImageData(x + 2, y) = rData(r)
            Else
                If ehTarget = 1 Then
                    Colors.tRGBToHSL r, g, b, h, s, v
                    Colors.tHSLToRGB h, s, floatLookup(lData(Int(v * 255))), r, g, b
                    ImageData(x, y) = b
                    ImageData(x + 1, y) = g
                    ImageData(x + 2, y) = r
                Else
                    Colors.fRGBtoHSV floatLookup(r), floatLookup(g), floatLookup(b), h, s, v
                    Colors.fHSVtoRGB h, s, floatLookup(lData(Int(v * 255))), rFloat, gFloat, bFloat
                    ImageData(x, y) = Int(bFloat * 255)
                    ImageData(x + 1, y) = Int(gFloat * 255)
                    ImageData(x + 2, y) = Int(rFloat * 255)
                End If
                
            End If
            
        Next x
            If Not toPreview Then
                If (y And progBarCheck) = 0 Then
                    If userPressedESC() Then Exit For
                    SetProgBarVal y + finalY
                End If
            End If
        Next y
        
    'Local histogram
    Else
        
        If Not toPreview Then Message "Equalizing image..."
        
        'Prep the pixel iterator
        Dim cPixelIterator As pdPixelIterator
        Set cPixelIterator = New pdPixelIterator
        
        If cPixelIterator.InitializeIterator(srcDIB, ehRadius, ehRadius, kernelShape) Then
            
            If ehTarget = 0 Then
                NumOfPixels = cPixelIterator.LockTargetHistograms_RGBA(rValues, gValues, bValues, aValues, False)
            Else
                NumOfPixels = cPixelIterator.LockTargetHistograms_Luminance(lValues)
            End If
            
            'Loop through each pixel in the image, applying the filter as we go
            For x = initXStride To finalXStride Step qvDepth
                
                'Based on the direction we're traveling, reverse the interior loop boundaries as necessary.
                If directionDown Then
                    startY = initY
                    stopY = finalY
                    yStep = 1
                Else
                    startY = finalY
                    stopY = initY
                    yStep = -1
                End If
                
                'Process the next column.  This step is pretty much identical to the row steps above (but in a vertical direction, obviously)
                For y = startY To stopY Step yStep
                
                    'With a local histogram successfully built for the area surrounding this pixel, we can now proceed
                    ' with processing the local histogram.
                    
                    'Start by retrieving the color at this pixel location.
                    b = ImageData(x, y)
                    g = ImageData(x + 1, y)
                    r = ImageData(x + 2, y)
                    
                    'Partially equalize each histogram
                    scaleFactor = 255 / NumOfPixels
                    
                    'RGB
                    If ehTarget = 0 Then
                    
                        rData(0) = CDbl(rValues(0)) * scaleFactor
                        If r > 0 Then
                            For i = 1 To r
                                rData(i) = rData(i - 1) + (scaleFactor * CDbl(rValues(i)))
                            Next i
                        End If
                        
                        gData(0) = CDbl(gValues(0)) * scaleFactor
                        If g > 0 Then
                            For i = 1 To g
                                gData(i) = gData(i - 1) + (scaleFactor * CDbl(gValues(i)))
                            Next i
                        End If
                        
                        bData(0) = CDbl(bValues(0)) * scaleFactor
                        If b > 0 Then
                            For i = 1 To b
                                bData(i) = bData(i - 1) + (scaleFactor * CDbl(bValues(i)))
                            Next i
                        End If
                        
                        'Clamp all lookup table values
                        If rData(r) > 255 Then rData(r) = 255
                        If gData(g) > 255 Then gData(g) = 255
                        If bData(b) > 255 Then bData(b) = 255
                        
                        'Adaptive histogram equalization can often lead to enormously different values.
                        ' To try and mediate this, we average the new value with the original value.
                        b = (b + bData(b)) \ 2
                        g = (g + gData(g)) \ 2
                        r = (r + rData(r)) \ 2
                        
                        'Apply the equalized value to the image
                        ImageData(x, y) = b
                        ImageData(x + 1, y) = g
                        ImageData(x + 2, y) = r
                        
                    'Luminance
                    Else
                        
                        If ehTarget = 1 Then
                            Colors.tRGBToHSL r, g, b, h, s, v
                        Else
                            Colors.fRGBtoHSV floatLookup(r), floatLookup(g), floatLookup(b), h, s, v
                        End If
                        
                        lData(0) = CDbl(lValues(0)) * scaleFactor
                        vLong = Int(v * 255)
                        If vLong > 0 Then
                            For i = 1 To vLong
                                lData(i) = CDbl(lData(i - 1)) + (scaleFactor * CDbl(lValues(i)))
                            Next i
                        End If
                        
                        If lData(vLong) > 255 Then lData(vLong) = 255
                        v = (v + floatLookup(lData(vLong))) / 2
                        
                        If ehTarget = 1 Then
                            Colors.tHSLToRGB h, s, v, r, g, b
                            ImageData(x, y) = b
                            ImageData(x + 1, y) = g
                            ImageData(x + 2, y) = r
                        Else
                            Colors.fHSVtoRGB h, s, v, rFloat, gFloat, bFloat
                            ImageData(x, y) = Int(bFloat * 255)
                            ImageData(x + 1, y) = Int(gFloat * 255)
                            ImageData(x + 2, y) = Int(rFloat * 255)
                        End If
                        
                    End If
                    
                    'Move the iterator in the correct direction
                    If directionDown Then
                        If y < finalY Then NumOfPixels = cPixelIterator.MoveYDown
                    Else
                        If y > initY Then NumOfPixels = cPixelIterator.MoveYUp
                    End If
                    
                Next y
                
                'Reverse y-directionality on each pass
                directionDown = Not directionDown
                If x < finalXStride Then NumOfPixels = cPixelIterator.MoveXRight
                
                'Update the progress bar every (progBarCheck) lines
                If Not toPreview Then
                    If (x And progBarCheck) = 0 Then
                        If userPressedESC() Then Exit For
                        SetProgBarVal x
                    End If
                End If
                    
            Next x
            
            'Release the pixel iterator and second copy of the source image
            If ehTarget = 0 Then
                cPixelIterator.ReleaseTargetHistograms_RGBA rValues, gValues, bValues, aValues
            Else
                cPixelIterator.ReleaseTargetHistograms_Luminance lValues
            End If
            
        End If
        
        srcDIB.eraseDIB
    
    End If
    
    'With our work complete, point ImageData() away from the DIB and deallocate it
    CopyMemory ByVal VarPtrArray(ImageData), 0&, 4
    Erase ImageData
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    finalizeImageData toPreview, dstPic
    
End Sub

Private Sub btsKernelShape_Click(ByVal buttonIndex As Long)
    UpdatePreview
End Sub

Private Sub btsMode_Click(ByVal buttonIndex As Long)
    UpdateRadiusVisibility
    UpdatePreview
End Sub

Private Sub btsTarget_Click(ByVal buttonIndex As Long)
    UpdatePreview
End Sub

Private Sub cmdBar_OKClick()
    Process "Equalize", , GetLocalParamString(), UNDO_LAYER
End Sub

Private Sub cmdBar_RequestPreviewUpdate()
    UpdatePreview
End Sub

Private Sub Form_Activate()
    
    'Apply translations and visual themes
    ApplyThemeAndTranslations Me
    
    'Request a preview
    cmdBar.markPreviewStatus True
    UpdatePreview
    
End Sub

Private Sub Form_Load()
    
    cmdBar.markPreviewStatus False
    
    btsTarget.AddItem "RGB", 0
    btsTarget.AddItem "luminance", 1
    btsTarget.AddItem "value", 2
    btsTarget.ListIndex = 0
    
    btsMode.AddItem "global", 0
    btsMode.AddItem "local", 1
    btsMode.ListIndex = 0
    
    Interface.PopKernelShapeButtonStrip btsKernelShape, PDPRS_Rectangle
    
    UpdateRadiusVisibility
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

'If the user changes the position and/or zoom of the preview viewport, the entire preview must be redrawn.
Private Sub pdFxPreview_ViewportChanged()
    UpdatePreview
End Sub

Private Sub sltRadius_Change()
    UpdatePreview
End Sub

Private Sub UpdateRadiusVisibility()
    sltRadius.Visible = CBool(btsMode.ListIndex = 1)
    btsKernelShape.Visible = CBool(btsMode.ListIndex = 1)
End Sub

Private Sub UpdatePreview()
    If cmdBar.previewsAllowed Then EqualizeHistogram GetLocalParamString(), True, pdFxPreview
End Sub

Private Function GetLocalParamString() As String
    GetLocalParamString = BuildParamList("target", btsTarget.ListIndex, "mode", btsMode.ListIndex, "kernelShape", btsKernelShape.ListIndex, "radius", sltRadius.Value)
End Function




