---
description: Xcode projesini derle ve testleri çalıştır
---
# turbo-all

**Adımlar**

// turbo
1. Build al:
   ```bash
   xcodebuild -scheme Algo-Trading -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
   ```

// turbo
2. Test çalıştır:
   ```bash
   xcodebuild -scheme Algo-Trading -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
   ```

3. Build başarılı olduktan sonra commit at.
