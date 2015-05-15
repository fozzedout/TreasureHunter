EnableExplicit

UseOGGSoundDecoder()

; tasks before possible release
;---------------------------------------------------------
; done - player physics - fall if not on platform
; done - player keyboard movement
; done - enemy platform walk detection - can't walk off the platforms
; done - collecting treasure
; done - going through doors
; done - death
; done - hi score persisted

#ShowFPS = 0

Enumeration
  #Move_Right1
  #Move_Right2
  #Move_Left1
  #Move_Left2
  #Move_Jump_Left
  #Move_Jump_Right
EndEnumeration

Enumeration
  #SpriteSheet
EndEnumeration

Enumeration
  #GameState_Loading
  #GameState_Intro
  #GameState_Game
  #GameState_GameOverWin
  #GameState_GameOverDied
  #GameState_Credits
EndEnumeration

Enumeration
  #Facing_Right
  #Facing_Left
EndEnumeration

Enumeration
  #SpriteType_Platform
  #SpriteType_Ladder
  #SpriteType_Door
  #SpriteType_Treasure
  #SpriteType_Enemy
  #SpriteType_Player
EndEnumeration

#TileSize = 16
#GameWidth  = 320
#GameHeight = 240

Global SeedRandomizer.i = ElapsedMilliseconds()
Global ScreenSelection.i = 1 ; Intro Screen
Global FullScreenMode.i = #False

Global quit = #False

Structure strPoint
  x.i
  y.i
EndStructure

Structure strSize
  width.i
  height.i
  Bottom.i
  Right.i
EndStructure

Structure strSpriteInSheet
  Location.strPoint
  Size.strSize
  TotalFrames.i
EndStructure

Structure strSprite
  OnScreen.strPoint
  InSheet.strSpriteInSheet
  FacingDirection.i
  AnimationCountDown.i
  AnimationFrame.i
EndStructure

Structure strPlatform Extends strSprite
  Type.i
  Bottom.i
  Right.i
EndStructure

Structure strSpriteWithValue Extends strSprite
  Value.i
EndStructure

Structure strEnemy Extends strSpriteWithValue
  MinimumWalkLeft.i
  MaximumWalkRight.i
EndStructure

Structure strCharacter Extends strSpriteWithValue
  Dead.i
EndStructure

Structure strLoot Extends strSpriteWithValue
  Collected.i
EndStructure

Structure strLevel
  RandomSeedValue.i
  List Enemies.strEnemy()
  List Platform.strPlatform() ; 20 x 7 = 140
  List loot.strLoot()
  List doors.strSpriteWithValue()
EndStructure

Global GameState.i = #GameState_Loading
Global NewList AssetsToLoad.s()
AddElement(AssetsToLoad()) : AssetsToLoad() = "simples_pimples8.png"

Global player.strCharacter
Global LootCollected.i = 0
Global HighScore.i = 0
Global Level.strLevel

Global gameFadeOut.i = 255
Global pauseScene.i = #False
Global scale.f = 1.0

#RoomSizeX = 19
#RoomSizeY = 14

Structure strDoor
  x.i
  y.i
  destination.i
EndStructure

Global Dim roomPlan.s(#RoomSizeX, #RoomSizeY)

Procedure DrawSprite(*pSprite.strSprite)
  Protected x.i = *pSprite\InSheet\Location\x
  Protected y.i = *pSprite\InSheet\Location\y
  
  y + (#TileSize * *pSprite\FacingDirection)
  
  If *pSprite\InSheet\TotalFrames > 1
    x + (*pSprite\AnimationFrame * #TileSize)
  EndIf
  
  *pSprite\AnimationCountDown - 1
  
  ClipSprite(#SpriteSheet, x, y, #TileSize, #TileSize)
  DisplayTransparentSprite(#SpriteSheet, *pSprite\OnScreen\x, *pSprite\OnScreen\y, gameFadeOut)
EndProcedure

Procedure.i IsCollision(*pSprite1.strSprite, *pSprite2.strSprite)
  ProcedureReturn Bool(*pSprite1\OnScreen\x < *pSprite2\OnScreen\x+#TileSize And 
                       *pSprite1\OnScreen\x+#TileSize > *pSprite2\OnScreen\x And 
                       *pSprite1\OnScreen\y < *pSprite2\OnScreen\y+#TileSize And 
                       *pSprite1\OnScreen\y+#TileSize > *pSprite2\OnScreen\y)
EndProcedure

Procedure GenerateRoomPlan(seed, lastSeed)
  ; rules for generating platforms
  ; only blank tiles can be written on
  ; generate the roomPlan outer wall first
  ; within that roomPlan, deposit numerous ladders (between 15-30) of varying lengths (1-5)
  ; build platforms that connect the top and bottom of ladders across the screen
  
  ;===========================================================================================
  ; reset roomPlan - generate the roomPlan outer wall first
  ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -
  Protected x.i
  Protected y.i
  For x = 0 To #RoomSizeX
    For y = 0 To #RoomSizeY
      If x = 0 Or x = #RoomSizeX Or y = 0 Or y = #RoomSizeY
        roomPlan(x,y) = "#"
      Else
        roomPlan(x,y) = ""
      EndIf
    Next
  Next
  ;===========================================================================================
  
  
  ;===========================================================================================
  ; within that roomPlan, deposit numerous ladders (between 15-30) of varying lengths (2-6)
  ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -
  Protected LadderCountMax.i = Random(17, 7)
  Protected LadderCount.i = 0
  Dim ladderPosition.s(#RoomSizeX, #RoomSizeY)
  
  While LadderCount < LadderCountMax
    Protected LadderCreated.i = #True
    
    x = Random(#RoomSizeX - 1, 1)
    y = Random(#RoomSizeY - 2, 2)
    
    Protected i.i
    For i = 1 To 2
      If ladderPosition(x  ,y) <> "" Or 
         ladderPosition(x+1,y) <> "" Or 
         ladderPosition(x-1,y) <> ""
        ; can't place ladder here, either hitting the outer wall, or another ladder horizontally adjacent
        LadderCreated = #False
        
        ; try again
        Break
      Else
        ladderPosition(x, y) = "!"
      EndIf
      
      y + 1
    Next
    LadderCount + 1
    
    If LadderCreated And LadderCount = LadderCountMax
      ; final sweep, make sure that every row is reachable
      For y = 2 To #RoomSizeY - 1
        Protected RowHasLadder.i = #False
        For x = 0 To #RoomSizeX
          If ladderPosition(x,y) = "!"
            RowHasLadder = #True
            Break
          EndIf
        Next
        
        If RowHasLadder = #False
          LadderCreated = #False
          Break
        EndIf
      Next
      
    EndIf
    
    If LadderCreated = #False
      ; clear all the ladders, and try again
      LadderCount = 0
      For x = 0 To #RoomSizeX
        For y = 0 To #RoomSizeY
          ladderPosition(x,y) = ""
        Next
      Next
    EndIf
    
  Wend
  
  ; copy generated ladder into the roomPlan
  If LadderCreated
    For x = 0 To #RoomSizeX
      For y = 0 To #RoomSizeY
        If ladderPosition(x,y) <> ""
          roomPlan(x,y) = ladderPosition(x,y)
          ;        ladderPosition(x,y) = ""
        EndIf
      Next
    Next
  EndIf
  ;===========================================================================================
  
  ;===========================================================================================
  ; generate connecting platforms for the top of each ladder, every other row has a platform
  ; which may or may not be there 
  ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -
  
  For x = 1 To #RoomSizeX - 1
    For y = 2 To #RoomSizeY - 1 Step 2
      If roomPlan(x,y) = ""
        If roomPlan(x,y+1) = "!" ; a ladder is directly below the platform, then connect it
          roomPlan(x,y) = "!"
        ElseIf roomPlan(x,y-2) = "!" ; a ladder is a space above a possible the platform, then a platform exists
          roomPlan(x,y) = "#"
        ElseIf Random(100, 0) > 80
          roomPlan(x,y) = "#"
        EndIf
      EndIf
    Next
  Next
  
  ; now sweep to connect isolated platforms or ladders
  For y = 2 To #RoomSizeY - 1 Step 2
    For x = 1 To #RoomSizeX - 1
      
      If roomPlan(x,y) = "#" Or roomPlan(x,y) = "!"
        Protected IsIsolated.i = #True
        
        ; check for isolation left to right of selected platform
        Protected sweepX.i
        For sweepX = x + 1 To #RoomSizeX - 1
          If roomPlan(sweepX,y) = "!"
            IsIsolated = #False
            Break
          ElseIf roomPlan(sweepX,y) = ""
            IsIsolated = #True
            Break
          EndIf
        Next
        
        ; if thought to be isolated left to right, now check right to left
        If IsIsolated
          For sweepX = x - 1 To 1 Step -1
            If roomPlan(sweepX,y) = "!"
              IsIsolated = #False
              Break
            ElseIf roomPlan(sweepX,y) = ""
              IsIsolated = #True
              Break
            EndIf
          Next
        EndIf
        
        ; if the platform is isolated, fill in the blanks for the whole row towards the left ladder
        If IsIsolated
          ; find the ladder on that row
          For sweepX = 1 To #RoomSizeX - 1
            If roomPlan(sweepX,y) = "!"
              
              If sweepX < x
                Protected fillInX.i
                For fillInX = sweepX + 1 To x - 1
                  If roomPlan(fillInX,y) = ""
                    roomPlan(fillInX,y) = "#"
                  EndIf
                Next
              Else
                For fillInX = sweepX - 1 To x + 1 Step -1
                  If roomPlan(fillInX,y) = ""
                    roomPlan(fillInX,y) = "#"
                  EndIf
                Next
              EndIf
              
              Break
            EndIf
          Next
          
        EndIf
        
      EndIf
      
    Next
  Next
  ;===========================================================================================
  
  ;===========================================================================================
  ; now for the enemies
  ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -
  Protected enemyType.i
  For y = 1 To #RoomSizeY - 1 Step 2
    Select Random(100)
      Case 0 To 40
        enemyType = 0
      Case 41 To 70
        enemyType = 1
      Case 71 To 90
        enemyType = 2
      Default
        enemyType = 3
    EndSelect
    
    Repeat
      x = Random(#RoomSizeX - 1, 1)
    Until roomPlan(x, y) = "" And roomPlan(x, y+1) <> ""
    roomPlan(x, y) = Str(enemyType)
  Next
  ;===========================================================================================
  
  ;===========================================================================================
  ; now for the doors - 4 - 7 in total.
  ; to ensure a connecting door back to the roomPlan you've just come from (the seed), keep going 
  ; through random numbers until you hit on the number of the roomPlan you've come from. any more 
  ; doors are numbers from that number, but duplicates are not allowed
  ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -
  Protected totalDoors.i = 5
  NewList doors.strDoor()
  AddElement(doors())
  doors()\destination = lastSeed
  
  While ListSize(doors()) < totalDoors
    Protected testSeed.i = Random(25)
    
    If testSeed <> seed
      Protected duplicateFound.i = #False
      ForEach doors()
        If doors()\destination = testSeed
          duplicateFound = #True
          Break
        EndIf
      Next
      If Not duplicateFound
        AddElement(doors())
        doors()\destination = testSeed
      EndIf
    EndIf
  Wend
  
  ; we now have the doors leading off to dirrection rooms, now to place them
  ForEach doors()
    Repeat
      doors()\x = Random(#RoomSizeX - 1, 1)
      doors()\y = Random(#RoomSizeY - 1, 1)
    Until roomPlan(doors()\x, doors()\y) = "" And roomPlan(doors()\x, doors()\y+1) <> ""
    roomPlan(doors()\x, doors()\y) = Chr(65 + doors()\destination)
  Next
  ;===========================================================================================
  
  ;===========================================================================================
  ; now for the treasure
  ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -
  For i = 1 To Random(20, 10)
    Protected treasureValue.i = Random(21, 1)
    Repeat
      x = Random(#RoomSizeX - 1, 1)
      y = Random(#RoomSizeY - 1, 1)
    Until roomPlan(x, y) = "" And roomPlan(x, y+1) = "#"
    roomPlan(x, y) = Chr(96 + treasureValue)
  Next
  
  ;===========================================================================================  
EndProcedure

Procedure GenerateLevel(pLevel.i, pPreviousLevel.i)
  Protected platformTheme.i = Random(13, 0)
  
  Level\RandomSeedValue = pLevel
  
  RandomSeed(SeedRandomizer + Level\RandomSeedValue)
  
  GenerateRoomPlan(pLevel, pPreviousLevel)
  
  ClearList( Level\Platform() )
  ClearList( Level\doors() )
  ClearList( Level\Enemies() )
  ClearList( Level\loot() )
  
  Protected x, y
  For x = 0 To #RoomSizeX
    For y = 0 To #RoomSizeY
      If roomPlan(x,y) = "#"
        AddElement(Level\Platform())
        With Level\Platform()
          \Type = #SpriteType_Platform
          \InSheet\Location\x = platformTheme * #TileSize
          \InSheet\Location\y = 64
          \OnScreen\x = x * #TileSize
          \OnScreen\y = y * #TileSize
          If y > 0 And roomPlan(x,y-1) = "#"
            \FacingDirection = #Facing_Left
          EndIf
        EndWith
      ElseIf roomPlan(x,y) = "!"
        AddElement(Level\Platform())
        With Level\Platform()
          \Type = #SpriteType_Ladder
          \InSheet\Location\x = platformTheme * #TileSize
          \InSheet\Location\y = 96
          \OnScreen\x = x * #TileSize
          \OnScreen\y = y * #TileSize
        EndWith
      ElseIf roomPlan(x,y) >= "A" And roomPlan(x,y) <= "Z"
        AddElement(Level\doors())
        With Level\doors()
          \InSheet\Location\x = platformTheme * #TileSize
          \InSheet\Location\y = 112
          \OnScreen\x = x * #TileSize
          \OnScreen\y = y * #TileSize
          \Value = Asc( roomPlan(x,y) ) - 65
        EndWith
      ElseIf roomPlan(x,y) >= "a" And roomPlan(x,y) <= "z"
        AddElement(Level\loot())
        With Level\loot()
          ; starting cood -> 368, 656
          \Value = Asc( roomPlan(x,y) ) - 97
          \InSheet\Location\x = 368 + ((\Value % 3) * #TileSize)
          \InSheet\Location\y = 656 + ((\Value / 3) * #TileSize)
          \OnScreen\x = x * #TileSize
          \OnScreen\y = y * #TileSize
          \Value + 1
        EndWith
      ElseIf roomPlan(x,y) >= "0" And roomPlan(x,y) <= "9"
        AddElement(Level\Enemies())
        With Level\Enemies()
          ; starting cood -> 512, 864
          \Value = Asc( roomPlan(x,y) ) - 48
          \InSheet\Location\x = 512
          \InSheet\Location\y = 864 + ( \Value * #TileSize * 2 )
          \InSheet\TotalFrames = 2
          \OnScreen\x = x * #TileSize
          \OnScreen\y = y * #TileSize
          \FacingDirection = Random(#Facing_Left, #Facing_Right)
          \AnimationCountDown = Random(10, 1)
          \AnimationFrame = Random(1, 0)
          
          ; all enemies are correctly positioned on a platform
          ; now sweep for the row below to work out the walk min and max range
          Protected checkX.i
          For checkX = x To #RoomSizeX
            If roomPlan(checkX, y) = "#" Or roomPlan(checkX, y+1) = ""
              \MaximumWalkRight = checkX * #TileSize
              Break
            EndIf
          Next
          For checkX = x To 0 Step -1
            If roomPlan(checkX, y) = "#" Or roomPlan(checkX, y+1) = ""
              \MinimumWalkLeft = (checkX * #TileSize) + #TileSize
              Break
            EndIf
          Next
          
        EndWith
      EndIf
    Next
  Next
  
  With player
    \AnimationCountDown = 6
    \AnimationFrame = 1
    \FacingDirection = #Facing_Right
    \OnScreen\x = 16
    \OnScreen\y = 16
    \InSheet\Location\x = 512
    \InSheet\Location\y = 800
    \InSheet\TotalFrames = 2
    \Dead = #False
  EndWith
  
EndProcedure

Procedure Prepare()

  OpenFile(0, "highscore")
  If Lof(0) <> 0
    HighScore = ReadInteger(0)
  EndIf
  CloseFile(0)
  
  LootCollected = 0
  gameFadeOut = 255
  pauseScene = #False
  player\Dead = #False
  SeedRandomizer = ElapsedMilliseconds()
  
  GenerateLevel(0,1)
EndProcedure

Procedure GameLogic_Player()
  Protected stop = 0
  With player
    If KeyboardPushed(#PB_Key_A)
      \FacingDirection = #Facing_Left
      \OnScreen\x - 2
      ForEach Level\Platform()
        If IsCollision(@player, @Level\Platform())
          If Level\Platform()\Type = #SpriteType_Platform
            \OnScreen\x + 2
            Break
          EndIf
        EndIf
      Next
    EndIf
    If KeyboardPushed(#PB_Key_D)
      \FacingDirection = #Facing_Right
      \OnScreen\x + 2
      ForEach Level\Platform()
        If IsCollision(@player, @Level\Platform())
          If Level\Platform()\Type = #SpriteType_Platform
            \OnScreen\x - 2
            Break
          EndIf
        EndIf
      Next
    EndIf
    
    Protected OriginalY = \OnScreen\y
    Protected IsOnLadder = #False
    ; gravity
    If \OnScreen\y % (#TileSize / 4) > 0
      \OnScreen\y + ( \OnScreen\y % (#TileSize / 4) )
    Else
      \OnScreen\y + (#TileSize / 4)
    EndIf
    
    ForEach Level\Platform()
      If IsCollision(@player, @Level\Platform())
        \OnScreen\y = OriginalY
        Break
      EndIf
    Next
    
    If KeyboardPushed(#PB_Key_W)
      \OnScreen\y = OriginalY - 2
      IsOnLadder = #False
      ForEach Level\Platform()
        If IsCollision(@player, @Level\Platform())
          If Level\Platform()\Type <> #SpriteType_Ladder
            \OnScreen\y = OriginalY
          Else
            IsOnLadder = #True
          EndIf
        EndIf
      Next
      
      If Not IsOnLadder
        \OnScreen\y = OriginalY
          
        ForEach Level\Platform()
          If IsCollision(@player, @Level\Platform())
            If Level\Platform()\Type = #SpriteType_Ladder
              \OnScreen\y = OriginalY - 2
              Break
            EndIf
          EndIf
        Next
        
      EndIf
    EndIf
    
    If KeyboardPushed(#PB_Key_S)
      \OnScreen\y = OriginalY + 2
      IsOnLadder = #False
      ForEach Level\Platform()
        If IsCollision(@player, @Level\Platform())
          If Level\Platform()\Type <> #SpriteType_Ladder
            \OnScreen\y = OriginalY
          Else
            IsOnLadder = #True
          EndIf
        EndIf
      Next
      
      If Not IsOnLadder
        \OnScreen\y = OriginalY
          
        ForEach Level\Platform()
          If IsCollision(@player, @Level\Platform())
            If Level\Platform()\Type = #SpriteType_Ladder
              \OnScreen\y = OriginalY + 2
              Break
            EndIf
          EndIf
        Next
        
      EndIf
    EndIf
    
  
  EndWith
EndProcedure

Procedure GameLogic_Enemies()
  ForEach Level\Enemies()
    With Level\Enemies()
      If \AnimationCountDown <= 0
        \AnimationFrame + 1
        \AnimationCountDown = 10
      EndIf
      If \AnimationFrame >= \InSheet\TotalFrames
        \AnimationFrame = 0
      EndIf
      If \FacingDirection = #Facing_Left
        \OnScreen\x - 1
      Else
        \OnScreen\x + 1
      EndIf
      If \OnScreen\x < \MinimumWalkLeft
        \FacingDirection = #Facing_Right
      ElseIf \OnScreen\x + #TileSize > \MaximumWalkRight
        \FacingDirection = #Facing_Left
      EndIf
    EndWith
  Next
EndProcedure

Procedure GameLogic_Loot()
  With player
    ForEach Level\loot()
      If Not Level\loot()\Collected
      If IsCollision(@player, @Level\loot())
        LootCollected + Level\loot()\Value
        Level\loot()\Collected = #True
      EndIf
      EndIf
    Next
  EndWith
EndProcedure

Procedure GameLogic_Doors()
  If KeyboardReleased(#PB_Key_Return)
    With player
      ForEach Level\doors()
        If IsCollision(@player, @Level\doors())
          GenerateLevel(Level\doors()\Value, Level\RandomSeedValue)
        EndIf
      Next
    EndWith
  EndIf
EndProcedure

Procedure GameLogic()
  ExamineKeyboard()
  If KeyboardReleased(#PB_Key_Q)
    quit = #True
    ProcedureReturn
  EndIf
  
  If player\Dead
    If LootCollected > HighScore
      HighScore = LootCollected
      CreateFile(0, "highscore")
      WriteInteger(0, HighScore)
      CloseFile(0)
    EndIf
    
  If KeyboardReleased(#PB_Key_Return)
Prepare()
  EndIf
EndIf    
  
  If Not player\Dead
    GameLogic_Player()
    GameLogic_Enemies()
    GameLogic_Loot()
    GameLogic_Doors()
    
    ForEach Level\Enemies()
      If IsCollision(@player, @Level\Enemies())
       player\Dead = #True
       PlaySound(0)
       Break
      EndIf
    Next
    
  EndIf
  
EndProcedure

Procedure DrawScene()
  ClearScreen($000000)
  
  ForEach Level\Platform()
    DrawSprite(@Level\Platform())
  Next
  
  ForEach Level\doors()
    DrawSprite(@Level\doors())
  Next
  
  ForEach Level\loot()
    If Not Level\loot()\Collected
      DrawSprite(@Level\loot())
    EndIf
  Next
  
  ForEach Level\Enemies()
    DrawSprite(@Level\Enemies())
  Next
  
  DrawSprite(@player)
  
  StartDrawing(ScreenOutput())
  DrawingFont(FontID(0))
  DrawText(0, 0, "     Treasure Collected $" + RSet(Str(LootCollected), 5, "0") + "    Hi-Score $" + RSet(Str(HighScore), 5, "0") + "     ")
  StopDrawing()
  
    If player\Dead
    If gameFadeOut > 0
      gameFadeOut - 1
    EndIf
    StartDrawing(ScreenOutput())
    DrawingFont(FontID(0))
    DrawText(5, 32, "You have died. Game Over.")
    DrawText(5, 64, "You collected $"  + Str(LootCollected))
    DrawText(5, 128, "Press Enter to start again")
    StopDrawing()

  EndIf
EndProcedure

Procedure RenderFrame()
  Select ScreenSelection
    Case 1
      ; intro screen
      
    Case 2
      ; game screen
      GameLogic()
      DrawScene()
  EndSelect
  
  FlipBuffers()
EndProcedure

Procedure ScaleSprites()
  
EndProcedure

Procedure Loading(Type, Filename$)
  Static NbLoadedElements
  NbLoadedElements + 1
  
  If NbLoadedElements = 0 ; Finished the loading of all images and sounds, we can start the applications
    
  EndIf
EndProcedure

Procedure LoadingError(Type, Filename$)
  Debug Filename$ + ": loading error"
EndProcedure

Procedure LoadSprites()
  LoadSprite(#SpriteSheet, "simples_pimples8.png", #PB_Sprite_PixelCollision | #PB_Sprite_AlphaBlending )
  CompilerIf #PB_Compiler_OS <> 5 : Loading(0,"") : CompilerEndIf
  
  LoadFont(0,"Terminal", 5)
  
  LoadSound(0, "Icy Game Over.ogg", #PB_Sound_Streaming)
  
  Prepare()
EndProcedure

;=======================================================================================
CompilerIf #PB_Compiler_OS <> 5
  UsePNGImageDecoder()
  InitSprite()
  InitKeyboard()
  InitSound()
CompilerEndIf

ExamineDesktops()
If DesktopHeight(0) < DesktopWidth(0)
  scale = (DesktopHeight(0) ) / #GameHeight
Else
  scale = (DesktopWidth(0) ) / #GameWidth
EndIf

;  OpenWindow (0, 0, 0, width *scale, height *scale, "Test", #PB_Window_ScreenCentered | #PB_Window_BorderLess)
OpenWindow (0, 0, 0, #GameWidth*scale, #GameHeight*scale, "Treasure Hunter", #PB_Window_ScreenCentered ) ;| #PB_Window_BorderLess)
OpenWindowedScreen(WindowID(0), 0, 0, #GameWidth , #GameHeight , 1,0,0)

; CompilerEndIf

SetFrameRate(30)

CompilerIf #PB_Compiler_OS = 5
  BindEvent(#PB_Event_Loading, @Loading())
  BindEvent(#PB_Event_LoadingError, @LoadingError())
  BindEvent(#PB_Event_RenderFrame, @RenderFrame())
  
  FlipBuffers(); // start the rendering
CompilerEndIf

LoadSprites()

ScreenSelection = 2

CompilerIf #PB_Compiler_OS <> 5
  Repeat
    RenderFrame()
    WindowEvent()
  Until quit
CompilerEndIf

; IDE Options = PureBasic 5.22 LTS (Windows - x64)
; CursorPosition = 160
; FirstLine = 157
; Folding = 8---
; EnableUnicode
; EnableXP