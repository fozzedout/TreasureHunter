EnableExplicit

OpenConsole()
EnableGraphicalConsole(#True)

#RoomSizeX = 19
#RoomSizeY = 14

Structure strDoor
  x.i
  y.i
  destination.i
EndStructure

Global Dim roomPlan.s(#RoomSizeX, #RoomSizeY)

Procedure GenerateRoom(seed, lastSeed)
; rules for generating platforms
; only blank tiles can be written on
; generate the roomPlan outer wall first
; within that roomPlan, deposit numerous ladders (between 15-30) of varying lengths (1-5)
; build platforms that connect the top and bottom of ladders across the screen

  RandomSeed(seed)
  
;===========================================================================================
; reset roomPlan - generate the roomPlan outer wall first
;-------------------------------------------------------------------------------------------
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
;-------------------------------------------------------------------------------------------
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
;-------------------------------------------------------------------------------------------

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
;-------------------------------------------------------------------------------------------
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
;-------------------------------------------------------------------------------------------
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
;-------------------------------------------------------------------------------------------
For i = 1 To Random(20, 10)
  Protected treasureValue.i = Random(21, 1)
  Repeat
    x = Random(#RoomSizeX - 1, 1)
    y = Random(#RoomSizeY - 1, 1)
  Until roomPlan(x, y) = "" And roomPlan(x, y+1) <> ""
  roomPlan(x, y) = Chr(96 + treasureValue)
Next

;===========================================================================================

EndProcedure

GenerateRoom(Random(25), 26)

ClearConsole()
Define x,y
For x = 0 To #RoomSizeX
  For y = 0 To #RoomSizeY
    ConsoleLocate(x,y)
    Print( roomPlan(x,y) )

  Next
Next

Input()

; IDE Options = PureBasic 5.22 LTS (Windows - x64)
; CursorPosition = 291
; FirstLine = 240
; Folding = -
; EnableUnicode
; EnableXP