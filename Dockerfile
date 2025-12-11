# STAGE 1: Build
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# Copy specific project file
COPY ["Hotel/Hotel.csproj", "Hotel/"]
RUN dotnet restore "Hotel/Hotel.csproj"

# Copy source and build
COPY . .
WORKDIR "/src/Hotel"
RUN dotnet build "Hotel.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "Hotel.csproj" -c Release -o /app/publish /p:UseAppHost=false

# STAGE 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS final
WORKDIR /app
EXPOSE 80
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Hotel.dll"]
