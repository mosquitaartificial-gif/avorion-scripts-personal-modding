
function isEnqueueing()
    return Keyboard():keyPressed(KeyboardKey.LShift) or Keyboard():keyPressed(KeyboardKey.RShift)
end
